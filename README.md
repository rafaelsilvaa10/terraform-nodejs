
Passar suas envs

criar uma chave ssh
aws ec2 --region us-east-1  create-key-pair --key-name rafa --query 'KeyMaterial' --output text > chave.pem

