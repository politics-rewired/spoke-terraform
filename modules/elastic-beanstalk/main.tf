##################################################
## IAM Roles and profiles
##################################################
resource "aws_iam_instance_profile" "beanstalk_service" {
  name = "${var.aws_client_tag}-spoke-beanstalk-service-user"
  role = "${aws_iam_role.beanstalk_service.name}"
}

resource "aws_iam_instance_profile" "beanstalk_ec2" {
  name = "${var.aws_client_tag}-spoke-beanstalk-ec2-user"
  role = "${aws_iam_role.beanstalk_ec2.name}"
}

resource "aws_iam_role" "beanstalk_service" {
  name = "${var.aws_client_tag}-spoke-beanstalk-service-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "elasticbeanstalk.amazonaws.com"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "elasticbeanstalk"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_role" "beanstalk_ec2" {
  name = "${var.aws_client_tag}-spoke-beanstalk-ec2-role"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "beanstalk_service" {
  name       = "${var.aws_client_tag}-spoke-elastic-beanstalk-service"
  roles      = ["${aws_iam_role.beanstalk_service.id}"]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkService"
}

resource "aws_iam_policy_attachment" "beanstalk_service_health" {
  name       = "${var.aws_client_tag}-spoke-elastic-beanstalk-service-health"
  roles      = ["${aws_iam_role.beanstalk_service.id}"]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkEnhancedHealth"
}

resource "aws_iam_policy_attachment" "beanstalk_ec2_web" {
  name       = "${var.aws_client_tag}-spoke-elastic-beanstalk-ec2-web"
  roles      = ["${aws_iam_role.beanstalk_ec2.id}"]
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws_iam_policy_attachment" "beanstalk_ec2_docker" {
  name       = "${var.aws_client_tag}-spoke-elastic-beanstalk-ec2-docker"
  roles      = ["${aws_iam_role.beanstalk_ec2.id}"]
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkMulticontainerDocker"
}

resource "aws_iam_policy_attachment" "beanstalk_ec2_s3_access" {
  name       = "${var.aws_client_tag}-spoke-elastic-beanstalk-ec2-s3-access"
  roles      = ["${aws_iam_role.beanstalk_ec2.id}"]
  policy_arn = "${var.s3_bucket_access_role_arn}"
}

##################################################
## Elastic Beanstalk
##################################################

# Create admin Elastic Beanstalk application
# Source: https://www.terraform.io/docs/providers/aws/r/elastic_beanstalk_application.html
resource "aws_elastic_beanstalk_application" "spoke_admin" {
  name        = "${var.aws_client_tag}-SpokeAdmin"
  description = "EB instance to handle long-lived admin Spoke requests."

  tags = {
    Name               = "${var.client_name_friendly} Spoke Admin EB"
    "user:client"      = "${var.aws_client_tag}"
    "user:stack"       = "${var.aws_stack_tag}"
    "user:application" = "spoke"
  }
}

# Create EB Environment
# Source: https://www.terraform.io/docs/providers/aws/r/elastic_beanstalk_environment.html
resource "aws_elastic_beanstalk_environment" "spoke_admin" {
  name                = "${var.aws_client_tag}-SpokeAdmin-production"
  description         = "Production Spoke admin version."
  application         = "${aws_elastic_beanstalk_application.spoke_admin.name}"
  solution_stack_name = "${var.eb_solution_stack_name}"

  tags = {
    Name               = "${var.client_name_friendly} Spoke Admin EB Version"
    "user:client"      = "${var.aws_client_tag}"
    "user:stack"       = "${var.aws_stack_tag}"
    "user:application" = "spoke"
  }

  # EC2 Instance Settings
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "${var.instance_type}"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "RootVolumeType"
    value     = "${var.instance_volume_type}"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "RootVolumeSize"
    value     = "${var.instance_volume_size}"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "RootVolumeIOPS"
    value     = "${var.instance_volume_iops}"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "EC2KeyName"
    value     = "${var.ssh_key_name}"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SecurityGroups"
    value     = "${join(",", var.security_groups)}"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = "${aws_iam_instance_profile.beanstalk_ec2.name}"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = "${aws_iam_role.beanstalk_service.name}"
  }

  # Custom VPC
  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = "${var.vpc_id}"
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = "${join(",", var.vpc_subnets)}"
  }

  setting {
    namespace = "${"aws:ec2:vpc"}"
    name      = "${"ELBSubnets"}"
    value     = "${join(",", var.elb_subnets)}"
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "${var.public_ip}"
  }

  # Auto Scaling group
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = "${var.min_instance}"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = "${var.max_instance}"
  }

  # Scaling triggers
  setting {
    namespace = "${"aws:autoscaling:trigger"}"
    name      = "${"BreachDuration"}"
    value     = "${var.as_breach_duration}"
  }

  setting {
    namespace = "${"aws:autoscaling:trigger"}"
    name      = "${"LowerBreachScaleIncrement"}"
    value     = "${var.as_lower_breach_scale_increment}"
  }

  setting {
    namespace = "${"aws:autoscaling:trigger"}"
    name      = "${"LowerThreshold"}"
    value     = "${var.as_lower_threshold}"
  }

  setting {
    namespace = "${"aws:autoscaling:trigger"}"
    name      = "${"MeasureName"}"
    value     = "${var.as_measure_name}"
  }

  setting {
    namespace = "${"aws:autoscaling:trigger"}"
    name      = "${"Period"}"
    value     = "${var.as_period}"
  }

  setting {
    namespace = "${"aws:autoscaling:trigger"}"
    name      = "${"Statistic"}"
    value     = "${var.as_statistic}"
  }

  setting {
    namespace = "${"aws:autoscaling:trigger"}"
    name      = "${"Unit"}"
    value     = "${var.as_unit}"
  }

  setting {
    namespace = "${"aws:autoscaling:trigger"}"
    name      = "${"UpperBreachScaleIncrement"}"
    value     = "${var.as_upper_breachs_scale_increment}"
  }

  setting {
    namespace = "${"aws:autoscaling:trigger"}"
    name      = "${"UpperThreshold"}"
    value     = "${var.as_upper_threshold}"
  }

  # Configure rolling deployments for your application code.
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "DeploymentPolicy"
    value     = "${var.deployment_policy}"
  }

  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "IgnoreHealthCheck"
    value     = "${var.ignore_healthcheck}"
  }

  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "SystemType"
    value     = "${var.healthreporting}"
  }

  # Configure the default listener (port 80) on a classic load balancer.
  setting {
    namespace = "${"aws:elb:listener:80"}"
    name      = "${"InstancePort"}"
    value     = "${var.port}"
  }

  setting {
    namespace = "${"aws:elb:listener:80"}"
    name      = "${"ListenerEnabled"}"
    value     = "${var.enable_http}"
  }

  # Configure additional listeners on a classic load balancer.
  setting {
    namespace = "${"aws:elb:listener:443"}"
    name      = "${"ListenerProtocol"}"
    value     = "${"HTTPS"}"
  }

  setting {
    namespace = "${"aws:elb:listener:443"}"
    name      = "${"InstancePort"}"
    value     = "${var.port}"
  }

  setting {
    namespace = "${"aws:elb:listener:443"}"
    name      = "${"SSLCertificateId"}"
    value     = "${var.ssl_certificate_id}"
  }

  setting {
    namespace = "${"aws:elb:listener:443"}"
    name      = "${"ListenerEnabled"}"
    value     = "${var.enable_https}"
  }

  # Node.js Platform Options
  # https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/command-options-specific.html#command-options-nodejs
  setting {
    namespace = "aws:elasticbeanstalk:container:nodejs"
    name      = "NodeCommand"
    value     = "${var.node_cmd}"
  }

  setting {
    namespace = "aws:elasticbeanstalk:container:nodejs"
    name      = "NodeVersion"
    value     = "${var.node_version}"
  }

  setting {
    namespace = "aws:elasticbeanstalk:container:nodejs"
    name      = "ProxyServer"
    value     = "${var.proxy_server}"
  }

  # Run the AWS X-Ray daemon to relay trace information from your X-Ray integrated Node.js application.
  setting {
    namespace = "aws:elasticbeanstalk:xray"
    name      = "XRayEnabled"
    value     = "${var.xray_enable}"
  }

  # Spoke environment variables
  dynamic "setting" {
    for_each = var.spoke_env

    content {
      namespace = "aws:elasticbeanstalk:application:environment"
      name      = setting.key
      value     = setting.value
    }
  }
}