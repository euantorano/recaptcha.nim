## reCAPTCHA support for Nim, supporting rendering a capctcha and verifying a user's response.

import asyncdispatch, httpclient, json

const
  VerifyUrl: string = "https://www.google.com/recaptcha/api/siteverify"
  CaptchaScript: string = r"""<script src="https://www.google.com/recaptcha/api.js" async defer></script>"""
  CaptchaElementStart: string = r"""<div class="g-recaptcha" data-sitekey=""""
  CaptchaElementEnd: string = r""""></div>"""

type
  ReCaptcha* = object
    ## reCAPTCHA client information, used to render the reCAPTCHA input and verify user responses.
    secret: string
      ## The reCAPTCHA secret key.
    siteKey: string
      ## The reCAPTCHA site key.

  CaptchaVerificationError* = object of Exception
    ## Error thrown if something goes wrong whilst attempting to verify a captcha response.

proc initReCaptcha*(secret, siteKey: string): ReCaptcha =
  ## Initialise a ReCaptcha instance with the given secret key and site key.
  ##
  ## The secret key and site key can be generated at https://www.google.com/recaptcha/admin
  result = ReCaptcha(
    secret: secret,
    siteKey: siteKey
  )

proc render*(rc: ReCaptcha): string =
  ## Render the required code to display the captcha.
  result = CaptchaElementStart
  result.add(rc.siteKey)
  result.add(CaptchaElementEnd)
  result.add("\n")
  result.add(CaptchaScript)

proc `$`*(rc: ReCaptcha): string =
  ## Render the required code to display the captcha.
  result = rc.render()

proc checkVerification(mpd: MultipartData): Future[bool] {.async, raises: [CaptchaVerificationError].} =
  let
    client = newAsyncHttpClient()
    response = await client.post(VerifyUrl, multipart=mpd)
    jsonContent = parseJson(response.body)
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

  result = if success != nil: success.getBVal() else: false

proc verify*(rc: ReCaptcha, reCaptchaResponse, remoteIp: string): Future[bool] {.async, raises: [CaptchaVerificationError].} =
  ## Verify the given reCAPTCHA response, from the given remote IP.
  let multiPart = newMultipartData({
    "secret": rc.secret,
    "response": reCaptchaResponse,
    "remoteip": remoteIp
  })
  result = await checkVerification(multiPart)

proc verify*(rc: ReCaptcha, reCaptchaResponse: string): Future[bool] {.async, raises: [CaptchaVerificationError].} =
  ## Verify the given reCAPTCHA response.
  let multiPart = newMultipartData({
    "secret": rc.secret,
    "response": reCaptchaResponse,
  })
  result = await checkVerification(multiPart)

when not defined(nimdoc) and isMainModule:
  import os, jester

  var captcha: ReCaptcha

  proc buildFormResponse(): string =
    result = r"""<form method="post" enctype="multipart/form-data">"""
    result.add(captcha.render())
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
