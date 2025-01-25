# Autenticação e Autorização de Usuários

## Contexto

O sistema precisa garantir que apenas usuários autenticados possam utilizá-lo, além disso os arquivos armazenados devem estar devidamente governandos para evitar o acesso indevido aos arquivos e dados persistidos.

Também partimos de alguns pressupostos sobre a arquitetura, conforme combinados em outras reuniões de planejamento:
- O sistema será hospedado no AWS
- Os arquivos dos usuários ficarão armazenados em buckets do S3
- Os micro serviços individuais serão construídos em funções Lambda

### Requisitos Funcionais

- Cadastro e autenticação de usuários com de usuário e senha
- Proteção dos endpoints externos para que sejam acessíveis somente quando autorizados
- Gestão de acesso aos arquivos armazenados no S3, de modo que cada usuário possa subir ou baixar seus próprios arquivos

### Desafios

- Garantir segurança das credenciais e dados dos usuários, restringindo seu acesso apenas quando forem necessários pelo sistema
- Possibilitar a exposição de endpoints autenticados externos para acesso ao sistema, considerando que nosso padrão de acesso irá se tratar de arquivos pesados (vídeos) que exigem maior tolerância para tempo de conectividade.

## Definição de arquitetura

### Provedor de identidade para cadastro e autenticação

A opção escolhida deve possibilitar o cadastro externo de clientes e prover opções de autenticação dos mesmos para as APIs externas.

#### Opções Consideradas
- Amazon Cognito: Utilizamos os "user pools" do AWS para fazer a autenticação e cadastro dos usuários.
- Terceiros: Utilizar outros provedores de autenticação para login dos usuários como Auth0, Stytch, Azure AD, etc.
- Construção própria: Construir nosso próprio serviço de controle de usuários, obtendo mairo possibilidade de customização sobre ele.

#### Opção escolhida: Amazon Cognito

Como nossa infraestrutura ficará centralizada na Amazon, faz sentido utilizar uma solução que seja integrada com outros sistemas, especialmente quando se trata de autenticação. Trago mais detalhes sobre este ponto nas próximas definições.

Não temos nenhuma necessidade que exija integração com provedores terceiros. Caso isso venha a ser um necessdade futura, o Amazon Cognito também permite integrações com uma série de serviços externos, dando margém para escalabilidade.

Também não há nenhuma necessidade que exijam um sistema customizado de gestão de usuários que não seja coberta pelo Amazon Cognito. O esforço operacional para garantir todas as capacidades de segurança pertinentes de tal sistema também seria muito maior do que utilizar a opção pronta.

### 2 Exposição de APIs autenticadas

Precisamos disponibilizar acesso externo das apis do sistema hospedadas em Lambda através de endpoints HTTP. Os endpoints devem estar protegidos com autenticação das requisições recebidas para impedir acesso indevido.

Consideramos que temos dois tipos de acesso externo ao nosso sistema:
    - Comunicação com os serviços
    - Transferência de arquivos

Optamos tomar estatégias diferentes sobre como cada tipo de acesso será resolvido

#### 2.1 Comunicação com os serviços

##### Opções Consideradas
- Api Gateway: Serviço mais abstrado e com maior conveniênica para configuração. Integra com o Lambda, Cognito e outros serviços do AWS, porém possuí algumas limitações para capacidade, algumas que são notáveis para nosso sistema são:
    - máximo de 10k requisições/segundo
    - máximo de 30 segundos de timeout
    - máximpo de 10MB para o tamanho do payload
- Application Load Balancer: Não temos as limitações do Api Gateway e possibilita funcionalidades de balanceamento de carga, possibilitando maior escalabilidade de uma forma geral. Por outro lado, é uma ferramenta maix complexa e temos maior esforço para configurar e gerir a autenticação, roteamento e tratamento das requisições.

##### Opção Escolhida: Api Gateway

Apesar de possibilitar escalabilidade muito superior, acreditamos que os requisitos atuais do sistema podem ser atendidos pelo Api Gateway. Por se tratar de uma API interna apenas para comunicação, acreditamos que o número de requisições ficará dentro da capacidade do Api Gateway.

O Application Load Balancer poderia ser útil para escalabilidade de balanceamento de carga, no entanto isto não é uma preocupação levantada nos requisitos e, caso seja algo relevante no futuro, também podemos integrá-lo com o Api Gateway para fazer uma arquitetura de migração.


#### 2.2 Exposição de endpoints para transferência de arquivos

##### Opções Consideradas
- Lambda Functions: Podemos realizar transferência utilizando Lambda functions como intermediário. No caso de upload, o arquivo do cliente seria enviado para a lambda que por sua vez acessaria a API para escrever o arquivo no S3.
- S3 Pre-signed URLs: Outra opção é utilizar pre-signed urls do S3, que possibilitam acesso e temporário para upload e download de arquivos a um path fixado do S3.

##### Opção Escolhida: S3 Pre-signed URLs.

Como estamos lidando com vídeos, a transferência de arquivos será um dos maiores custos do nosso sistema, escalando com cada intermediário adicionado no caminho da operação. Temos um alto risco de extrapolar o orçamento dependendo da implementação desta funcionalidade.

Sendo assim, quanto mais direta for possível montar esta conexão, mais eficiente será o sistema. Determinamos que o caminho mais apropriado então seria utilizara própria api do S3 para transferência dos vídeos.

A funcionalidade de "pre-signed urls" do S3 permite gerar URLs temporárias para operações em arquivos específicos do S3. Nosso estratégia é retornar estas urls para o client de modo que a transferência do arquivo seja feita diretamente do client ao S3, sem onerar custos em serviços intermediários.

Considerações de Segurança:
- A Pre-signed URL será gerada pelas funções Lambda do sistema e retornadas para os usuários.
- Durante a criação da URL dentro da Lambda, iremos especificar a operação a ser realizada (PUT ou GET), o path do objeto referente e o tempo de expiração. O client não poderá alterar nenhuma destas condições, então em um cenário de extrafiltragem da url, apenas o arquivo em específico para onde ela aponta seria comprometido.
- Também podemos enriquecer a segurança através de outras políticas do IAM, como restringindo o acesso através do IP utilizando roles específicas, utilizando a integração de identity pools com os user pools do cognito, entre outras. Não foi possível explorar estas opções devido à limitações do Lab que nos foi disponibilizado no AWS, mas é algo válido para ser implementado em uma versão real da aplicação.


## Visão geral do fluxo de Autenticação:

1. Usuário é autenticado pela funcionalidade de login do Amazon Cognito.
2. Token JWT gerado durante a autenticação é fornecido às requisições do API Gateway.
3. Api Gateway valida o token com o Amazon Cognito por um "authorizer" integrado.
4. Token JWT e informações de autenticação são fornecidas como parâmetros para o handler da Lambda.
5. Lambda pode realizar solicitações ao Amazon Cognito para consultar o token e outras informações do usuário.
6. Dados do usuário podem ser transmitidos para acesso em outros serviços.

![diagrama do fluxo de autenticacao]()


## Visão geral do fluxo de solicitação das pre-signed urls:

1. Lambda solicita geração da pre-signed url para api do S3
2. Resposta da Lambda com url é enviada ao API Gateway
3. Resposta com url é retornada ao client acessado pelo usuário
4. Client realiza a operação utilizando a pre signed url diretamente com o S3

![Diagrama do fluxo de solicitação das urls]()