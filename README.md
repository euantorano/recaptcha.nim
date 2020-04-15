# reCAPTCHA

reCAPTCHA support for Nim, supporting rendering a capctcha and verifying a user's response. This library supports reCaptcha from:
* https://www.google.com/recaptcha/admin
* https://recaptcha.net
* https://hcaptcha.com

## Installation

```
nimble install recaptcha
```

## Usage

Before using this modul, be sure to register at the reCaptcha providers website in order to get your client secret and site key. These are required to use this module. Register at:
* [Google reCaptcha](https://www.google.com/recaptcha/admin)
* [hCaptcha](https://hcaptcha.com)

Once you have your client secret and site key, you should create an instance of `ReCaptcha`:

```nim
import recaptcha

let captcha = initReCaptcha("MY_SECRET_KEY", "MY_SITE_KEY", Google)
#let captcha = initReCaptcha("MY_SECRET_KEY", "MY_SITE_KEY", RecaptchaNet) <-- using recaptcha.net
#let captcha = initReCaptcha("MY_SECRET_KEY", "MY_SITE_KEY", Hcaptcha)     <-- using hcaptcha.com
```

You can print out the required HTML code to show the reCAPTCHA element on the page using the `render` method:

```nim
import recaptcha

let captcha = initReCaptcha("MY_SECRET_KEY", "MY_SITE_KEY", Google)

echo captcha.render()
```

(or you can use the `$` stringify shortcut to achieve the same thing)

Once the user has submitted the captcha back to you, you should verify their response:

```nim
import recaptcha, asyncdispatch

let captcha = initReCaptcha("MY_SECRET_KEY", "MY_SITE_KEY", Google)

let response = await captcha.verify(THEIR_RESPONSE)
```

If the user is a valid user, `response` will be `true`. Otherwise, it will be `false`.

Should there be an issue with the data sent to the reCAPTCHA service, an exception of type `CaptchaVerificationError` will be thrown.

In most cases, captchas are used within a HTML `<form>` element. In this case, the user's response will be available within form parameter named `g-recaptcha-response` for `Google` and `reCaptha.net` and within `h-recaptcha-repsonse` for `hCaptcha`.

You may also optionally pass the user's IP address along to reCAPTCHA during verification as an extra check:

```nim
import recaptcha, asyncdispatch

let captcha = initReCaptcha("MY_SECRET_KEY", "MY_SITE_KEY", Google)

let response = await captcha.verify(THEIR_RESPONSE, USERS_IP_ADDRESS)
```

# Example

The example below uses `Google` as validator.

```nim
import recaptcha, asyncdispatch, jester
from strutils import format

const htmlForm = """
<form method="POST" action="/verify">
  <input type="text" name="email">
  <input type="password" name="password">
  <div class="g-recaptcha" data-sitekey="$1"></div>
  <button type="submit">Verify</button>
  <script src="https://www.google.com/recaptcha/api.js" async defer></script>
</form>
"""

let 
  secretKey = "123456789"
  siteKey   = "987654321"
  captcha   = initReCaptcha(secretKey, siteKey, Google)

routes:
  get "/login":
    resp(htmlForm.format(siteKey))

  post "/verify":
    let checkCap = await captcha.verify(@"g-recaptcha-response")
    if checkCap:
      resp("Welcome")
    else:
      resp("You failed the captcha")
```
