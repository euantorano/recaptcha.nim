## reCAPTCHA support for Nim, supporting rendering a capctcha and verifying a user's response.

import asyncdispatch, httpclient, json

const
  VerifyUrl: string = "https://www.google.com/recaptcha/api/siteverify"
  VerifyUrlReplace: string = "https://recaptcha.net/recaptcha/api/siteverify"
  CaptchaScript: string = r"""<script src="https://www.google.com/recaptcha/api.js" async defer></script>"""
  CaptchaScriptReplace: string = r"""<script src="https://recaptcha.net/recaptcha/api.js" async defer></script>"""
  CaptchaElementStart: string = r"""<div class="g-recaptcha" data-sitekey=""""
  CaptchaElementEnd: string = r""""></div>"""
  NoScriptElementStart: string = r"""<noscript>
  <div>
    <div style="width: 302px; height: 422px; position: relative;">
      <div style="width: 302px; height: 422px; position: absolute;">
        <iframe src="https://www.google.com/recaptcha/api/fallback?k="""
  NoScriptElementStartReplace: string = r"""<noscript>
  <div>
    <div style="width: 302px; height: 422px; position: relative;">
      <div style="width: 302px; height: 422px; position: absolute;">
        <iframe src="https://recaptcha.net/recaptcha/api/fallback?k="""
  NoScriptElementEnd: string = r"""" frameborder="0" scrolling="no"
                style="width: 302px; height:422px; border-style: none;">
        </iframe>
      </div>
    </div>
    <div style="width: 300px; height: 60px; border-style: none;
                   bottom: 12px; left: 25px; margin: 0px; padding: 0px; right: 25px;
                   background: #f9f9f9; border: 1px solid #c1c1c1; border-radius: 3px;">
      <textarea id="g-recaptcha-response" name="g-recaptcha-response"
                   class="g-recaptcha-response"
                   style="width: 250px; height: 40px; border: 1px solid #c1c1c1;
                          margin: 10px 25px; padding: 0px; resize: none;" >
      </textarea>
    </div>
  </div>
</noscript>"""

type
  ReCaptcha* = object
    ## reCAPTCHA client information, used to render the reCAPTCHA input and verify user responses.
    secret: string
      ## The reCAPTCHA secret key.
    siteKey: string
      ## The reCAPTCHA site key.
    replace: bool
      ## Default use www.google.com.If true, use "www.recaptcha.net".
      ## Docs in https://developers.google.com/recaptcha/docs/faq#can-i-use-recaptcha-globally.

  CaptchaVerificationError* = object of Exception
    ## Error thrown if something goes wrong whilst attempting to verify a captcha response.

proc initReCaptcha*(secret, siteKey: string, replace = false): ReCaptcha =
  ## Initialise a ReCaptcha instance with the given secret key and site key.
  ##
  ## The secret key and site key can be generated at https://www.google.com/recaptcha/admin
  result = ReCaptcha(
    secret: secret,
    siteKey: siteKey,
    replace: replace
  )

proc render*(rc: ReCaptcha, includeNoScript: bool = false): string =
  ## Render the required code to display the captcha.
  ##
  ## If you set `includeNoScript` to `true`, then the `<noscript>` element required to support browsers without JS will be included in the output.
  ## By default, this is disabled as you have to modify the settings for your reCAPTCHA domain to set the security level to the minimum level to support this.
  ## For more information, see the reCAPTCHA support page: https://developers.google.com/recaptcha/docs/faq#does-recaptcha-support-users-that-dont-have-javascript-enabled
  result = CaptchaElementStart
  result.add(rc.siteKey)
  result.add(CaptchaElementEnd)
  result.add("\n")
  if not rc.replace:
    result.add(CaptchaScript)
  else:
    result.add(CaptchaScriptReplace)

  if includeNoScript:
    result.add("\n")
    if not rc.replace:
      result.add(NoScriptElementStart)
    else:
      result.add(NoScriptElementStartReplace)
    result.add(rc.siteKey)
    result.add(NoScriptElementEnd)

proc `$`*(rc: ReCaptcha): string =
  ## Render the required code to display the captcha.
  result = rc.render()

proc checkVerification(mpd: MultipartData, replace: bool): Future[bool] {.async.} =
  let
    client = newAsyncHttpClient()
  var response: AsyncResponse
  if not replace:
    response = await client.post(VerifyUrl, multipart=mpd)
  else:
    response = await client.post(VerifyUrlReplace, multipart=mpd) 

  let
    jsonContent = parseJson(await response.body)
    success = jsonContent.getOrDefault("success")
    errors = jsonContent.getOrDefault("error-codes")

  if errors != nil:
    for err in errors.items():
      case err.getStr()
      of "missing-input-secret":
        raise newException(CaptchaVerificationError, "The secret parameter is missing.")
      of "invalid-input-secret":
        raise newException(CaptchaVerificationError, "The secret parameter is invalid or malformed.")
      of "missing-input-response":
        raise newException(CaptchaVerificationError, "The response parameter is missing.")
      of "invalid-input-response":
        raise newException(CaptchaVerificationError, "The response parameter is invalid or malformed.")
      else: discard

  result = if success != nil: success.getBool() else: false

proc verify*(rc: ReCaptcha, reCaptchaResponse, remoteIp: string): Future[bool] {.async.} =
  ## Verify the given reCAPTCHA response, from the given remote IP.
  let multiPart = newMultipartData({
    "secret": rc.secret,
    "response": reCaptchaResponse,
    "remoteip": remoteIp
  })
  result = await checkVerification(multiPart, rc.replace)

proc verify*(rc: ReCaptcha, reCaptchaResponse: string): Future[bool] {.async.} =
  ## Verify the given reCAPTCHA response.
  let multiPart = newMultipartData({
    "secret": rc.secret,
    "response": reCaptchaResponse,
  })
  result = await checkVerification(multiPart, rc.replace)

when not defined(nimdoc) and isMainModule:
  import os, jester

  var captcha: ReCaptcha

  proc buildFormResponse(): string =
    result = r"""<form method="post" enctype="multipart/form-data">"""
    result.add(captcha.render(true))
    result.add("\n")
    result.add(r"""<input type="submit"/>""")
    result.add("\n")
    result.add("</form>")

  routes:
    get "/":
      resp buildFormResponse()

    post "/":
      try:
        echo("Result for captcha: ", waitFor captcha.verify(request.formData["g-recaptcha-response"].body, request.host))
      except:
        echo "[ERROR]: " & getCurrentExceptionMsg()

      resp buildFormResponse()

  proc main() =
    let
      secretKey = getEnv("RECAPTCHA_SECRET")
      siteKey = getEnv("RECAPTCHA_SITEKEY")

    captcha = initReCaptcha(secretKey, siteKey)

    runForever()

  main()
