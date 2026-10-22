# Host Your CV on AWS — Muhammad Anas

**Student roll number:** `23l-3005`  
**Email:** `anas165922@gmail.com`  
**AWS Region:** `ap-southeast-2` (Asia Pacific — Sydney)

## AWS resources

- S3 bucket: `cv-23l-3005`
- EC2 instance name: `cv-ec2-23l-3005`
- EC2 IAM role: `cv-ec2-role-23l-3005`
- Lambda function: `cv-func-23l-3005`
- Lambda IAM role: `cv-lambda-role-23l-3005`
- Required tags: `Owner=23l-3005`, `Course=cloud`

## Project structure

```text
aws-cv/
├── README.md
├── evidence.txt
├── collect-evidence.sh
├── site/
│   ├── index.html
│   ├── style.css
│   └── cv.pdf
├── ec2/
│   ├── user-data.sh
│   └── sync-cv.sh
├── lambda/
│   └── lambda_function.py
└── iam/
    ├── ec2-trust.json
    ├── ec2-permissions.json
    ├── lambda-trust.json
    └── lambda-permissions.json
```

## Architecture

```text
Visitor --HTTP--> EC2 public IPv4 --> Nginx --> local copy of S3 site/
                         | EC2 instance role (read-only)
                         v
                    Private S3 bucket

Visitor --HTTPS--> Lambda Function URL --> Lambda execution role (read-only) --> Private S3 bucket
```

EC2 is intended to serve the files from its local web root and synchronize from S3 every five minutes. Lambda is intended to return HTML, CSS, PDF, and 404 responses. PDF bytes are base64 encoded for a Lambda Function URL response.

## Before submission — important

1. **Replace `site/cv.pdf`.** It is only a clearly marked placeholder because your actual CV PDF was not supplied. Upload your real CV PDF with the exact filename `cv.pdf` and keep it at or below 1 MB.
2. **Complete the placeholders in `site/index.html`.** Add your real education and skills. Update or remove the optional second project placeholder. Do not submit the square-bracketed template text as if it were real information.
3. Keep the S3 bucket private, with all four Block Public Access settings enabled and versioning enabled. Do not add a public bucket policy or public object ACL.
4. Review the IAM policies and ensure the roles and required tags match the assignment.
5. Run `collect-evidence.sh` and replace the placeholder content in `evidence.txt` with actual collected evidence.
6. Make the GitHub repository public if required by your instructor. Keep AWS endpoints/resources available until marking is complete.

## Evidence collection

Run the script with exactly three arguments:

```bash
./collect-evidence.sh cv-23l-3005 YOUR_EC2_PUBLIC_IP YOUR_LAMBDA_FUNCTION_URL
```

It creates/overwrites `evidence.txt` with these sections: `caller`, `public-access`, `versioning`, `objects`, `ec2-policy`, `lambda-policy`, `security-group`, `instance`, `endpoints`, `lambda-logs`, and `log-retention`. AWS CLI credentials and permissions are required. If a command fails, the script records the failure and continues. Review the resulting file and do not claim that failed tests passed.

## Access-denied test

The assignment asks for the actual output of a denied attempt to overwrite an S3 object. Run a safe test using a temporary local file from an environment using the EC2 role, for example:

```bash
printf 'permission test\n' > /tmp/cv-permission-test.txt
aws s3 cp /tmp/cv-permission-test.txt s3://cv-23l-3005/site/index.html
```

The upload is expected to fail with `AccessDenied` because the EC2 role has no `s3:PutObject`. Paste the actual output here. Do not fabricate output. Avoid testing delete operations against important files.

## EC2 sync log

Paste the last ten lines from the actual instance after the sync script has run:

```bash
sudo tail -n 10 /var/log/cv-sync.log
```

## Five short-answer questions

Use these as draft answers and adjust them to match what you actually configured and observed. Keep each answer within the assignment's five-sentence limit.

1. **Why roles instead of access keys? What could go wrong if keys were in user data?**  
   Roles provide temporary credentials and can be restricted to the minimum permissions needed. Access keys in user data could be exposed through scripts, logs, or console access; leaked long-lived keys could be reused outside the instance.

2. **What happens when someone opens the direct S3 address? Which setting causes it?**  
   With the bucket private, direct anonymous access should be denied. S3 Block Public Access and the absence of public bucket policies or ACLs prevent public access, while the application roles can still read the allowed objects. Record the actual result you observe.

3. **Explain the public Lambda Function URL permission. Why is it acceptable for Lambda but not the bucket?**  
   The Function URL's resource-based permission allows unauthenticated visitors to invoke the website handler as required by the assignment. The function role should only read the website objects it needs. Keeping S3 private prevents visitors from bypassing the application and accessing the bucket directly.

4. **Compare the two paths. What do you pay for with no visitors, and what if traffic grows 100 times?**  
   A running EC2 instance and its storage can incur charges even without visitors. Lambda generally charges based on requests and execution, although S3 and logging may still cost money. Lambda can scale automatically but may incur more usage charges or meet quotas; EC2 may need additional capacity to handle much higher traffic.

5. **You delete the EC2 instance. What do you lose and what remains?**  
   The EC2 website and its public IPv4 endpoint stop working, and instance-local runtime files are lost according to the storage deletion settings. S3, Lambda, IAM roles, the GitHub repository, and evidence remain unless separately deleted. A replacement instance may have a different public IPv4 address and instance ID.

## Current test status

During setup, the EC2 instance was running, HTTP port 80 was allowed by its security group, and the EC2 S3 read policy was inspected. The public EC2 website still could not be reached at the last test. The Lambda Function URL had also returned an internal server error earlier. Re-test both endpoints and record the actual outcomes in `evidence.txt`; do not represent either endpoint as working unless you verify it.

## Adapted material and AI assistance

This project scaffold was prepared with AI assistance. Add course materials and official AWS documentation you used, and follow your instructor's disclosure rules.
