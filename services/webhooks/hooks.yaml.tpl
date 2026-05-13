- id: deploy
  execute-command: /config/update-service.sh
  command-working-directory: /config
  response-message: Deployment request accepted
  trigger-rule-mismatch-http-response-code: 403
  http-methods:
    - POST
  pass-environment-to-command:
    - envname: HOOK_REPOSITORY
      source: payload
      name: repository
    - envname: HOOK_REF
      source: payload
      name: ref
    - envname: HOOK_IMAGE
      source: payload
      name: image
    - envname: HOOK_TAG
      source: payload
      name: tag
  trigger-rule:
    and:
      - match:
          type: payload-hmac-sha256
          secret: __WEBHOOK_SECRET__
          parameter:
            source: header
            name: X-Hub-Signature-256
      - match:
          type: value
          value: refs/heads/main
          parameter:
            source: payload
            name: ref
