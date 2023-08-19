# GitHub Action to deploy Helm Charts in EKS

This Action allows you to install & upgrade Helm Charts in EKS. By using this GitHub Action, you can automate the deployment of your Helm Charts in EKS easily. 

## Usage

```yaml
- name: Deploy Helm Chart to EKS Cluster
  uses: open-source-srilanka/eks-helm-client-github-action@v0.1.0
  env:
    REGION_CODE: <your-region-code>
    CLUSTER_NAME: <your-cluster-name>
  with:
    args: >
        bash -c "
            helm repo add bitnami https://charts.bitnami.com/bitnami;
            helm repo update;
            helm install bitnami/mysql --generate-name
        "
```

For more detailed information on how to use this action, please refer to this [example](https://github.com/open-source-srilanka/examples/tree/master/eks-helm-client-github-action).

## Inputs

</br>

| Name       |          Description        | Required |
|------------|-----------------------------| -------- |
| args       | commands need to execute    | True     |

## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".
Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Copyright (c) 2023 ProjectOSS