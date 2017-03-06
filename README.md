# reCAPTCHA

reCAPTCHA support for Nim, supporting rendering a capctcha and verifying a user's response.

## Installation

```
nimble install recaptcha
```

## Usage

Before using this modul, be sure to [register your site with Google](https://www.google.com/recaptcha/admin) in order to get your client secret and site key. These are required to use this module.

Once you have your client secret and site key, you should create an instance of `ReCaptcha`:

```nim
import recaptcha

let captcha = initReCaptcha(MY_SECRET_KEY, MY_SITE_KEY)
```

You can print out the required HTML code to show the reCAPTCHA element on the page using the `render` method:

```nim
import recaptcha

let captcha = initReCaptcha(MY_SECRET_KEY, MY_SITE_KEY)

echo captcha.render()
```

(or you can use the `$` stringify shortcut to achieve the same thing)

Once the user has submitted the captcha back to you, you should verify their response:

```nim
import recaptcha, asyncdispatch

let captcha = initReCaptcha(MY_SECRET_KEY, MY_SITE_KEY)

let response = await captcha.verify(THEIR_RESPONSE)
```

If the user is a valid user, `response` will be `true`. Otherwise, it will be `false`.

Should there be an issue with the data sent to the reCAPTCHA service, an exception of type `CaptchaVerificationError` will be thrown.

In most cases, captchas are used within a HTML `<form>` element. In this case, the user's response will be available within the `g-recaptcha-response` form parameter.

You may also optionally pass the user's IP address along to reCAPTCHA during verification as an extra check:

```nim
import recaptcha, asyncdispatch

let captcha = initReCaptcha(MY_SECRET_KEY, MY_SITE_KEY)

let response = await captcha.verify(THEIR_RESPONSE, USERS_IP_ADDRESS)
```
