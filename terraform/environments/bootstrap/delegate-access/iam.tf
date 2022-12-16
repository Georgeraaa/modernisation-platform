locals {
  account_name = try(regex("^bichard*.|^remote-supervisio*.", terraform.workspace), replace(terraform.workspace, regex("-[^-]*$", terraform.workspace), ""))
  account_data = jsondecode(file("../../../../environments/${local.account_name}.json"))
}

resource "aws_iam_account_alias" "alias" {
  count         = (local.account_data.account-type != "member-unrestricted") && !(contains(local.skip_alias, terraform.workspace)) ? 1 : 0
  provider      = aws.workspace
  account_alias = terraform.workspace
}

module "cross-account-access" {
  source = "github.com/ministryofjustice/modernisation-platform-terraform-cross-account-access?ref=v2.3.0"
  providers = {
    aws = aws.workspace
  }
  account_id             = local.modernisation_platform_account.id
  policy_arn             = "arn:aws:iam::aws:policy/AdministratorAccess"
  role_name              = "ModernisationPlatformAccess"
  additional_trust_roles = concat(tolist(data.aws_iam_roles.mp-sso-admin-access.arns), terraform.workspace == "testing-test" ? ["arn:aws:iam::${local.environment_management.account_ids[terraform.workspace]}:user/testing-ci"] : [])

}

module "ssm-cross-account-access" {
  source = "github.com/ministryofjustice/modernisation-platform-terraform-cross-account-access?ref=v2.3.0"
  providers = {
    aws = aws.workspace
  }
  account_id             = local.environment_management.account_ids["core-shared-services-production"]
  policy_arn             = data.aws_iam_policy_document.execution-combined-policy.json
  role_name              = "AWS-SSM-AutomationExecutionRole"
  additional_trust_statements = [data.aws_iam_policy_document.trust-relationship-policy.json]

}

data "aws_iam_policy_document" "SSM-Automation-Policy" {
  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["arn:aws:lambda:*:*:function:Automation*"]
    actions   = ["lambda:InvokeFunction"]
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "ec2:CreateImage",
      "ec2:CopyImage",
      "ec2:DeregisterImage",
      "ec2:DescribeImages",
      "ec2:DeleteSnapshot",
      "ec2:StartInstances",
      "ec2:RunInstances",
      "ec2:StopInstances",
      "ec2:TerminateInstances",
      "ec2:DescribeInstanceStatus",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:DescribeTags",
      "cloudformation:CreateStack",
      "cloudformation:DescribeStackEvents",
      "cloudformation:DescribeStacks",
      "cloudformation:UpdateStack",
      "cloudformation:DeleteStack",
    ]
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]
    actions   = ["ssm:*"]
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["arn:aws:sns:*:*:Automation*"]
    actions   = ["sns:Publish"]
  }
}

data "aws_iam_policy_document" "execution-policy" {
  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "resource-groups:ListGroupResources",
      "tag:GetResources",
      "ec2:DescribeInstances",
    ]
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["arn:aws:iam::*:role/AWS-SSM-AutomationExecutionRole"]
    actions   = ["iam:PassRole"]
  }
}

data "aws_iam_policy_document" "trust-relationship-policy" {
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.environment_management.account_ids["core-shared-services-production"]}:role/AWS-SSM-AutomationAdministrationRole"]
    }
  }

  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ssm.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "execution-combined-policy" {
  source_policy_documents = concat([data.aws_iam_policy_document.SSM-Automation-Policy.json, data.aws_iam_policy_document.execution-policy.json])
}


module "cicd-member-user" {
  count  = local.account_data.account-type == "member" ? 1 : 0
  source = "../../../modules/iam_baseline"
  providers = {
    aws = aws.workspace
  }
}

module "member-access" {
  count  = local.account_data.account-type == "member" && terraform.workspace != "testing-test" ? 1 : 0
  source = "github.com/ministryofjustice/modernisation-platform-terraform-cross-account-access?ref=v2.3.0"
  providers = {
    aws = aws.workspace
  }
  account_id             = local.modernisation_platform_account.id
  additional_trust_roles = [module.github-oidc[0].github_actions_role, one(data.aws_iam_roles.member-sso-admin-access.arns)]
  policy_arn             = aws_iam_policy.member-access[0].id
  role_name              = "MemberInfrastructureAccess"
}

#tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "member-access" {
  statement {
    #checkov:skip=CKV_AWS_108
    #checkov:skip=CKV_AWS_111
    #checkov:skip=CKV_AWS_107
    #checkov:skip=CKV_AWS_109
    #checkov:skip=CKV_AWS_110
    effect = "Allow"
    actions = [
      "acm-pca:*",
      "acm:*",
      "application-autoscaling:*",
      "applicationinsights:*",
      "athena:*",
      "autoscaling:*",
      "cloudfront:*",
      "cloudwatch:*",
      "dlm:*",
      "dms:*",
      "ds:CheckAlias",
      "ds:Describe*",
      "ds:List*",
      "ds:*Tags*",
      "ds:CancelSchemaExtension",
      "ds:CreateComputer",
      "ds:CreateAlias",
      "ds:CreateDirectory",
      "ds:CreateLogSubscription",
      "ds:CreateMicrosoftAD",
      "ds:CreateSnapshot",
      "ds:DeleteDirectory",
      "ds:DeleteLogSubscription",
      "ds:DeleteSnapshot",
      "ds:DeregisterCertificate",
      "ds:DeregisterEventTopic",
      "ds:DisableClientAuthentication",
      "ds:DisableLDAPS",
      "ds:DisableRadius",
      "ds:EnableClientAuthentication",
      "ds:EnableLDAPS",
      "ds:EnableRadius",
      "ds:RegisterCertificate",
      "ds:RegisterEventTopic",
      "ds:ResetUserPassword",
      "ds:RestoreFromSnapshot",
      "ds:StartSchemaExtension",
      "ds:UpdateDirectorySetup",
      "ds:UpdateNumberOfDomainControllers",
      "ds:UpdateRadius",
      "ds:UpdateSettings",
      "dynamodb:*",
      "ebs:*",
      "ec2:Describe*",
      "ec2:*SecurityGroup*",
      "ec2:*KeyPair*",
      "ec2:*Tags*",
      "ec2:*Volume*",
      "ec2:*Snapshot*",
      "ec2:*Ebs*",
      "ec2:*NetworkInterface*",
      "ec2:*Address*",
      "ec2:*Image*",
      "ec2:*Event*",
      "ec2:*Instance*",
      "ec2:*CapacityReservation*",
      "ec2:*Fleet*",
      "ec2:Get*",
      "ec2:SendDiagnosticInterrupt",
      "ec2:*LaunchTemplate*",
      "ec2:*PlacementGroup*",
      "ec2:*IdFormat*",
      "ec2:*Spot*",
      "ecr-public:*",
      "ecr:*",
      "ecs:*",
      "elasticfilesystem:*",
      "elasticloadbalancing:*",
      "events:*",
      "firehose:*",
      "glacier:*",
      "glue:*",
      "guardduty:get*",
      "iam:*",
      "kinesis:*",
      "kms:*",
      "lambda:*",
      "logs:*",
      "organizations:Describe*",
      "organizations:List*",
      "quicksight:*",
      "rds-db:*",
      "rds:*",
      "route53:*",
      "s3:*",
      "secretsmanager:*",
      "ses:*",
      "sns:*",
      "sqs:*",
      "ssm:*",
      "wafv2:*",
      "resource-groups:*",
      "redshift:*",
      "redshift-data:*",
      "redshift-serverless:*"
    ]
    resources = ["*"] #tfsec:ignore:AWS099 tfsec:ignore:AWS097
  }

  statement {
    effect = "Deny"
    actions = [
      "ec2:CreateVpc",
      "ec2:CreateSubnet",
      "ec2:CreateVpcPeeringConnection",
      "iam:AddClientIDToOpenIDConnectProvider",
      "iam:AddUserToGroup",
      "iam:AttachGroupPolicy",
      "iam:AttachUserPolicy",
      "iam:CreateAccountAlias",
      "iam:CreateGroup",
      "iam:CreateLoginProfile",
      "iam:CreateOpenIDConnectProvider",
      "iam:CreateSAMLProvider",
      "iam:CreateUser",
      "iam:CreateVirtualMFADevice",
      "iam:DeactivateMFADevice",
      "iam:DeleteAccountAlias",
      "iam:DeleteAccountPasswordPolicy",
      "iam:DeleteGroup",
      "iam:DeleteGroupPolicy",
      "iam:DeleteLoginProfile",
      "iam:DeleteOpenIDConnectProvider",
      "iam:DeleteSAMLProvider",
      "iam:DeleteUser",
      "iam:DeleteUserPermissionsBoundary",
      "iam:DeleteUserPolicy",
      "iam:DeleteVirtualMFADevice",
      "iam:DetachGroupPolicy",
      "iam:DetachUserPolicy",
      "iam:EnableMFADevice",
      "iam:RemoveClientIDFromOpenIDConnectProvider",
      "iam:RemoveUserFromGroup",
      "iam:ResyncMFADevice",
      "iam:UpdateAccountPasswordPolicy",
      "iam:UpdateGroup",
      "iam:UpdateLoginProfile",
      "iam:UpdateOpenIDConnectProviderThumbprint",
      "iam:UpdateSAMLProvider",
      "iam:UpdateUser"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Deny"
    actions = [
      "iam:AttachRolePolicy",
      "iam:DeleteRole",
      "iam:DeleteRolePermissionsBoundary",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePermissionsBoundary",
      "iam:PutRolePolicy",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateRole",
      "iam:UpdateRoleDescription"
    ]
    resources = ["arn:aws:iam::*:user/cicd-member-user"]
  }
}

resource "aws_iam_policy" "member-access" {
  count    = local.account_data.account-type == "member" ? 1 : 0
  provider = aws.workspace

  name        = "MemberInfrastructureAccessActions"
  description = "Restricted admin policy for member CI/CD to use"
  policy      = data.aws_iam_policy_document.member-access.json
}

module "instance-scheduler-access" {
  count  = local.account_data.account-type == "member" && terraform.workspace != "testing-test" ? 1 : 0
  source = "github.com/ministryofjustice/modernisation-platform-terraform-cross-account-access?ref=v2.3.0"
  providers = {
    aws = aws.workspace
  }
  account_id             = local.environment_management.account_ids["core-shared-services-production"]
  additional_trust_roles = [format("arn:aws:iam::%s:role/InstanceSchedulerLambdaFunctionPolicy", local.environment_management.account_ids["core-shared-services-production"])]
  policy_arn             = aws_iam_policy.instance-scheduler-access[0].id
  role_name              = "InstanceSchedulerAccess"
}

#tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "instance-scheduler-access" {
  statement {
    #checkov:skip=CKV_AWS_108
    #checkov:skip=CKV_AWS_111
    #checkov:skip=CKV_AWS_107
    #checkov:skip=CKV_AWS_109
    #checkov:skip=CKV_AWS_110
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeTags",
      "ec2:StartInstances",
      "ec2:StopInstances"
    ]
    resources = ["*"] #tfsec:ignore:AWS099 tfsec:ignore:AWS097
  }
  # checkov:skip=CKV_AWS_111: "Cannot restrict by KMS alias so leaving open"
  statement {
    sid       = "AllowToDecryptKMS"
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "kms:Decrypt"
    ]
  }
  # checkov:skip=CKV_AWS_111: "Will need to potentially create grants on multiple keys"
  statement {
    actions = [
      "kms:CreateGrant"
    ]
    resources = ["*"]
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}

resource "aws_iam_policy" "instance-scheduler-access" {
  count    = local.account_data.account-type == "member" ? 1 : 0
  provider = aws.workspace

  name        = "InstanceSchedulerAccessActions"
  description = "Restricted policy for use by the Instance Scheduler Lambda in member accounts"
  policy      = data.aws_iam_policy_document.instance-scheduler-access.json
}

# Testing-test member access - separate as need the testing user created in the testing account to be able to access as well
data "aws_iam_policy_document" "assume_role_policy" {
  version = "2012-10-17"

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "AWS"
      identifiers = ["arn:aws:iam::${local.modernisation_platform_account.id}:root",
        "arn:aws:iam::${local.environment_management.account_ids[terraform.workspace]}:user/testing-ci",
        one(data.aws_iam_roles.member-sso-admin-access.arns)
      ]
    }
  }
}

# IAM role to be assumed
resource "aws_iam_role" "testing_member_infrastructure_access_role" {
  count              = terraform.workspace == "testing-test" ? 1 : 0
  provider           = aws.workspace
  name               = "MemberInfrastructureAccess"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

# IAM role attached policy
resource "aws_iam_role_policy_attachment" "testing_member_infrastructure_access_role" {
  count      = terraform.workspace == "testing-test" ? 1 : 0
  provider   = aws.workspace
  role       = aws_iam_role.testing_member_infrastructure_access_role[0].id
  policy_arn = aws_iam_policy.member-access[0].arn
}

module "testing_instance-scheduler-access" {
  count  = terraform.workspace == "testing-test" ? 1 : 0
  source = "github.com/ministryofjustice/modernisation-platform-terraform-cross-account-access?ref=v2.3.0"
  providers = {
    aws = aws.workspace
  }
  account_id             = local.environment_management.account_ids["core-shared-services-production"]
  additional_trust_roles = [format("arn:aws:iam::%s:role/InstanceSchedulerLambdaFunctionPolicy", local.environment_management.account_ids["core-shared-services-production"]), format("arn:aws:iam::%s:root", local.environment_management.account_ids["testing-test"])]
  policy_arn             = aws_iam_policy.instance-scheduler-access[0].id
  role_name              = "InstanceSchedulerAccess"
}

# Create a parameter for the modernisation platform environment management secret ARN that can be used to gain
# access to the environments parameter when running a tf plan locally

resource "aws_ssm_parameter" "environment_management_arn" {
  provider = aws.workspace

  name  = "environment_management_arn"
  type  = "SecureString"
  value = data.aws_secretsmanager_secret.environment_management.arn

  tags = local.environments
}

# Create a parameter for the modernisation platform account id that can be used
# by providers in member accounts to assume a role in MP

resource "aws_ssm_parameter" "modernisation_platform_account_id" {
  provider = aws.workspace

  name  = "modernisation_platform_account_id"
  type  = "SecureString"
  value = local.environment_management.modernisation_platform_account_id

  tags = local.environments
}

# AWS Shield Advanced SRT (Shield Response Team) support role
module "shield_response_team_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5"
  providers = {
    aws = aws.workspace
  }
  trusted_role_services = ["drt.shield.amazonaws.com"]

  create_role       = true
  role_name         = "AWSSRTSupport"
  role_requires_mfa = false

  custom_role_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSShieldDRTAccessPolicy"]

  number_of_custom_role_policy_arns = 1
}

# Github OIDC provider
module "github-oidc" {
  count  = (local.account_data.account-type == "member" && terraform.workspace != "testing-test") ? 1 : 0
  source = "github.com/ministryofjustice/modernisation-platform-github-oidc-provider?ref=v2.0.0"
  providers = {
    aws = aws.workspace
  }
  additional_permissions = data.aws_iam_policy_document.oidc_assume_role_member[0].json
  github_repositories    = ["ministryofjustice/modernisation-platform-environments:*"]
  tags_common            = { "Name" = format("%s-oidc", terraform.workspace) }
  tags_prefix            = ""
}
data "aws_iam_policy_document" "oidc_assume_role_member" {
  count = local.account_data.account-type == "member" && terraform.workspace != "testing-test" ? 1 : 0
  statement {
    sid    = "AllowOIDCToAssumeRoles"
    effect = "Allow"
    resources = [
      format("arn:aws:iam::%s:role/member-delegation-%s-%s", local.environment_management.account_ids[format("core-vpc-%s", local.application_environment)], lower(local.business_unit), local.application_environment),
      format("arn:aws:iam::%s:role/modify-dns-records", local.environment_management.account_ids["core-network-services-production"]),
      format("arn:aws:iam::%s:role/modernisation-account-limited-read-member-access", local.environment_management.modernisation_platform_account_id),
      # the two below are required as sprinkler and cooker have development accounts but are in the sandbox vpc
      local.application_name == "sprinkler" ? format("arn:aws:iam::%s:role/member-delegation-garden-sandbox", local.environment_management.account_ids["core-vpc-sandbox"]) : format("arn:aws:iam::%s:role/modernisation-account-limited-read-member-access", local.environment_management.modernisation_platform_account_id),
      local.application_name == "cooker" ? format("arn:aws:iam::%s:role/member-delegation-house-sandbox", local.environment_management.account_ids["core-vpc-sandbox"]) : format("arn:aws:iam::%s:role/modernisation-account-limited-read-member-access", local.environment_management.modernisation_platform_account_id)
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalOrgID"
      values   = [data.aws_organizations_organization.root_account.id]
    }
    actions = ["sts:AssumeRole"]
  }

  # checkov:skip=CKV_AWS_111: "Cannot restrict by KMS alias so leaving open"
  statement {
    sid       = "AllowOIDCToDecryptKMS"
    effect    = "Allow"
    resources = ["*"]
    actions   = ["kms:Decrypt"]
  }

  statement {
    sid       = "AllowOIDCReadState"
    effect    = "Allow"
    resources = ["arn:aws:s3:::modernisation-platform-terraform-state/*", "arn:aws:s3:::modernisation-platform-terraform-state/"]
    actions = ["s3:Get*",
    "s3:List*"]
  }

  statement {
    sid       = "AllowOIDCWriteState"
    effect    = "Allow"
    resources = ["arn:aws:s3:::modernisation-platform-terraform-state/environments/members/*"]
    actions = ["s3:PutObject",
    "s3:PutObjectAcl"]
  }
}
