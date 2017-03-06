# Package

version       = "1.0.0"
author        = "Euan T"
description   = "reCAPTCHA support for Nim, supporting rendering a capctcha and verifying a user\'s response."
license       = "BSD3"

srcDir = "src"

# Dependencies

requires "nim >= 0.16.0"

task docs, "Build documentation":
  exec "nim doc2 -o:docs/recaptcha.html src/recaptcha.nim"
