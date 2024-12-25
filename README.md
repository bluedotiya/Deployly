# Deployly

<img src="./assets/logo.png" alt="Deployly" width="300" height="200">

**"The app that ups the apps!"**

Deployly is a mock platform built to demonstrate Secure CI/CD workflows.

---

## Features

- **Basic HTTPS Content Serving**: It serves HTTPS content... sometimes.
- **CI/CD Pipelines**: Automated builds that sometimes deploy to a mock Azure cloud enviorment.
- **Infinite Scalability**: In theory, not in practice.

---

## Tech Stack

- **CI/CD**: GitHub Actions
- **Provisioning**: Terraform
- **Configuration**: Ansible
- **Version Control**: Git

---

## Example Workflow

1. Developer pushes code to the repository.
2. GitHub Actions trigger the CI/CD pipeline, Run static analysis using Checkov.
3. Infrastructure is deployed to azure using terraform.
4. Ansible connects to the webserver to configure it.

---

## System design overview

1. Application gateway Resource that do the SSL offload & WAF
2. VM that runs apache2 as a webserver on port80 on internal subnet
3. Storage account that uses object storage to store relevent artificats and data
4. CMK & Key vault for blob storage storage

