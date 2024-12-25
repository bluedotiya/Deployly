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
2. VM that runs apache2 as a webserver on port 80 on internal subnet
3. Storage account that uses object storage to store relevent artificats and data
4. CMK & Key vault for blob storage storage

# Security meassure
1. Writing in a feedback loop with static code analysis tools, ensure the Infrastructe code is written in a secure manner - Secure code best practicies
2. Using TLS for communication with our application gateway - To prevent MitM attacks, data sniffing
3. Using Azure key vault along side a CMK to encrypt our storage account artifacts - to ensure that even if our data is exfiltrated, it cannot be used
4. Ensuring retension & and expirey dates for sensetive tokens or keys, CMK expire date & rotation, SAS Token expire date - limiting senstive resoucres leak
5. Network segregation, Key vault reside in a different subnet than Application servers - to prevent lateral movemnt in the worst case senario
6. Network NGS Policy to allow only explict traffic that is defined - to prevent data exfiltration 
7. Application gateway seperation between SNAT & DNAT - to prevent reconnaissance
8. Unit tests pipeline hardfails deployment pipeline (inline design) - Prevent deploying of unsafe code
9. Prevention of local users of storage account - this leave managed identify users the only possible option - Prevents using unmanaged users
10. Soft delete polices on important data - Ensure malicaious or accidental actos cannot fully delete critical data
11. Replication & data availablity - Ensure our information & artifiacts remines availables (C.I.A Principles)

