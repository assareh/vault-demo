resource "null_resource" "key" {
  provisioner "local-exec" {
    command = "echo \"${tls_private_key.hashicat.private_key_pem}\" > ${aws_key_pair.hashicat.key_name}"
  }

  provisioner "local-exec" {
    command = "chmod 600 *.pem"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f *.pem"
  }

}
