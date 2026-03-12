# Security Policy

## Supported Versions

Tiercel is actively maintained on the latest public release.

| Version        | Supported |
| -------------- | --------- |
| Latest release | ✅        |
| Older releases | ❌        |

Please reproduce security issues against the latest release before reporting when possible.

## Reporting a Vulnerability

If you believe you have found a security vulnerability in Tiercel, please report it **privately**.

Please use **GitHub Private Vulnerability Reporting / Security Advisories** for this repository.

Please **do not open a public GitHub issue** for potential vulnerabilities before we have had a chance to investigate and coordinate a fix.

## What to Include

To help validate and address the report quickly, please include:

- A clear description of the issue
- Affected version(s)
- Environment details, such as iOS version, Swift version, and integration method
- Steps to reproduce
- Proof of concept, sample code, logs, or screenshots if available
- Impact assessment and any suggested remediation, if known

## Scope

Tiercel is a download infrastructure library with logic around:

- background downloads
- resumable transfers
- task persistence and restoration
- task-state transitions
- thread-safe coordination
- response and file validation hooks

Because these areas can affect both correctness and trust boundaries, private reports are appreciated for issues that may lead to:

- unsafe file handling
- unexpected data exposure
- improper trust of unvalidated inputs or responses
- denial of service or resource exhaustion
- logic flaws with security impact in real applications

## Response Process

We will try to:

- acknowledge receipt within **7 days**
- investigate and validate the report
- work on a fix or mitigation when the issue is confirmed
- coordinate disclosure with the reporter after a fix is available

Response and remediation timelines may vary depending on severity, complexity, and maintainer availability, but good-faith reports are appreciated and taken seriously.

## Disclosure Guidelines

Please give us a reasonable opportunity to investigate and release a fix before any public disclosure.

We ask that reporters:

- avoid accessing or modifying data that does not belong to them
- avoid service disruption, destructive testing, or privacy violations
- keep details private until a fix or mitigation is ready

## Notes

Tiercel includes substantial logic related to thread safety, task lifecycle management, persistence, and download recovery. Reports that help identify, validate, and remediate issues in these areas are especially valuable.
