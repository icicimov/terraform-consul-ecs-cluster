vpc = {
    id                    = "<VPC-ID>"
    tag                   = "ECSTEST"
    owner_id              = "<OWNER-ID>"
    cidr_block            = "10.22.0.0/20"
    subnet_bits           = "4"
    sns_topic             = "arn:aws:sns:<AWS-REGION>:<OWNER-ID>:NotifyMe"
}
ecs = {
    cluster_name          = "ecs-example"
    instance_type         = "t2.micro"
    file_name             = "userdata_ecs_instance_asg.sh"
    role_arn              = "arn:aws:iam::<OWNER-ID>:role/ecsInstanceRole"
    termination_policies  = "NewestInstance,Default"
}
key_name                  = "ec2key"
consul = {
    data_center           = "DC-ECSTEST"
    instance_type         = "t2.micro"
    version               = "0.6.4"
    encrypt_key           = "<ENCRYPTION-KEY>"
    cert_download_user    = "user:password"
    servers               = "10.22.3.115,10.22.4.193,10.22.5.48"
}
app = {
    name                  = "nodejs-app"
    volume_mount          = "/data"
    enc_env               = "ECSTEST"
    oracle_jdk            = "8"
    elb_ssl_cert_arn      = "arn:aws:iam::<OWNER-ID>:server-certificate/<MY-CERT-ID>"
    elb_hc_uri            = "/health"
    listen_port_http      = "8080"
    listen_port_https     = "443"
    min_capacity          = "2"
    max_capacity          = "10"
    image                 = "igoratencompass/nodejs-app"
    version               = "latest"
    cpu                   = "1024"
    memory                = "128"
    file_name             = "nodejs-app-task-definition.json"
    role_arn              = "arn:aws:iam::<OWNER-ID>:role/ecsAutoscaleRole"
}
hap.instance_type         = "t2.micro"
enc_domain = {
    name                  = "mydomain.com"
    zone_id               = "<ZONE-ID>"
}