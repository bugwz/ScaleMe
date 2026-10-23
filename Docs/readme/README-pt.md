<div align="center">

<img src="../../Design/Logo/readme-logo.svg" width="96" height="96" alt="观我 · ScaleMe">

# 观我

### ScaleMe

[![iOS 17+](https://img.shields.io/badge/iOS-17%2B-black?logo=apple)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5-orange?logo=swift)](https://www.swift.org/)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blue)](https://developer.apple.com/xcode/swiftui/)
[![Bluetooth LE](https://img.shields.io/badge/Bluetooth-LE-0A3D91?logo=bluetooth)](https://www.bluetooth.com/)
[![Armazenamento no dispositivo](https://img.shields.io/badge/Data-On%20Device-2E8B57)](#data-storage-and-privacy)

Um app nativo para iOS que acompanha peso e composição corporal

**Observe as mudanças do seu corpo e acompanhe sua trajetória de saúde.**

[简体中文](../../README.md) | [繁體中文](README-zh-Hant.md) | [English](README-en.md) | [日本語](README-ja.md) | [Français](README-fr.md) | [Deutsch](README-de.md) | [Español](README-es.md) | [**Português**](README-pt.md) | [Русский](README-ru.md) | [한국어](README-ko.md)

</div>

观我 (ScaleMe) é um app nativo para iOS que registra peso e composição corporal de pessoas e famílias. Conecte balanças Bluetooth compatíveis ou insira medições manualmente e consulte o histórico e as tendências por perfil, dispositivo e período.

Não é necessário criar uma conta. Perfis, configurações dos dispositivos e medições ficam no dispositivo, sem envio a servidores do desenvolvedor e sem sincronização própria do app na nuvem. O usuário ativa o acesso ao Saúde da Apple e realiza as importações e exportações de arquivos.

<div align="center">

<a href="https://apps.apple.com/app/id6808930548">
  <img src="../../Design/Download/AppStoreBanner.png" width="100%" alt="Apresentação do ScaleMe e download na App Store">
</a>

</div>

## Principais recursos

### Medições e registros

- Encontrar e associar balanças Bluetooth compatíveis, mostrar o andamento e os dados disponíveis do dispositivo e salvar resultados estáveis.
- Registrar o peso manualmente, escolher data e hora e, se necessário, acrescentar valores de composição corporal exibidos pelo dispositivo, inclusive de medições anteriores.
- Consultar detalhes, atribuir registros a outro perfil ou excluí-los. Protocolos compatíveis podem ler o histórico da balança, identificar o perfil correspondente e remover duplicatas.
- Medições ao vivo são salvas primeiro em um arquivo local, antes de se tornarem registros definitivos e acionarem o compartilhamento com o Saúde habilitado. Falhas exibem o estado não salvo e uma opção de tentar novamente.

### Perfis familiares e tendências

- Criar vários perfis, gerenciar vários dispositivos e consultar separadamente os registros de cada pessoa.
- Escolher e ordenar indicadores de saúde na página inicial, com valores recentes, significado e faixas de referência aplicáveis.
- Filtrar tendências por perfil, dispositivo, período e indicador, observando mudanças em gráficos e no histórico.
- Widgets de tendências pequenos, médios e grandes na Tela de Início, cada um com escolhas independentes de indicador, período, dispositivo, perfil e exibição.

### Gerenciamento de dados e Saúde da Apple

- Importar e exportar configurações e medições separadamente ou juntas em arquivos JSON, além de excluir dados locais.
- Ler opcionalmente peso e percentual de gordura corporal do Saúde da Apple para o próprio perfil e gravar novas medições elegíveis no Saúde.
- Os controles de sincronização e as permissões do sistema são independentes. Medições Bluetooth, registros manuais e tendências continuam disponíveis com a sincronização desligada.

### Interface e acessibilidade

- Chinês simplificado e tradicional, inglês, japonês, francês, alemão, espanhol, português, russo e coreano, seguindo o sistema ou por escolha no app.
- Temas padrão e adaptado a alterações na percepção de cores, com aparência clara, escura ou do sistema.
- VoiceOver para estados de medição, gráficos, menus e formulários, com adaptação a Dynamic Type e Reduzir Movimento. Veja o escopo real na [validação de acessibilidade](../Accessibility.md).
- Dados familiares simulados permitem experimentar a interface sem uma balança. Alterações de registros nesse modo não são gravadas nos dados reais; os dados predefinidos retornam na próxima inicialização.

## Compatibilidade de dispositivos

O projeto implementa a análise das características padrão Bluetooth SIG de peso e composição corporal, além da análise de anúncios ou sessões de medição GATT de vários protocolos de fabricantes. Recursos e níveis de validação variam por protocolo; uma marca não garante suporte a todos os modelos.

- Encontrar um dispositivo, reconhecer seu nome ou cadastrar um protocolo não significa que a medição seja suportada.
- Testes com amostras validam a análise dos dados, não o funcionamento completo entre um iPhone e uma balança real.
- Medições ao vivo, composição corporal, leitura do histórico e configuração de autenticação dependem do protocolo. Campos não confirmados não são salvos como indicadores conhecidos.
- Regras declarativas de comunicação válidas podem ser importadas de arquivos JSON locais. O app não baixa protocolos de endereços remotos.

Consulte a [matriz de suporte a protocolos](../BluetoothProtocolSupport.md) para capacidades, níveis de validação e fontes de pesquisa, e as [regras de comunicação externas](../ExternalCommunicationRules.md) para o formato de extensão.

## Indicadores e estimativas

O app distingue valores originais do dispositivo de seus próprios cálculos. Peso, composição corporal fornecida pelo dispositivo, IMC calculado a partir do perfil e estimativas condicionais têm fontes e âmbitos de aplicação diferentes.

Em balanças de composição corporal reconhecidas, os valores do dispositivo ou protocolo têm prioridade. Valores ausentes só recebem estimativas experimentais quando há impedância principal válida, informações do perfil e condições adequadas do modelo. Balanças apenas de peso, registros manuais e importações do Saúde não acionam essas estimativas padrão. Sem impedância principal, o IMC não a substitui para estimar a composição corporal ausente.

Os cálculos são salvos com cada medição, separadamente dos valores originais. Alterar o perfil não recalcula automaticamente o histórico; atribuir um registro a outro perfil recalcula. Estimativas não são gravadas no Saúde da Apple. Faixas etárias, hipóteses de adaptação aos dispositivos e regras empíricas têm limitações; estimativas do app não são algoritmos oficiais dos fabricantes nem medições clínicas.

A seção de informações dos dados e as páginas de cálculo de cada indicador apresentam fórmulas, fontes e condições de aplicação. Os detalhes técnicos estão em [dados, sincronização e privacidade](../DataAndPrivacy.md). Os resultados de composição corporal servem para observar tendências, não para diagnóstico, tratamento ou decisões médicas.

<a id="data-storage-and-privacy"></a>

## Armazenamento e privacidade

### Armazenamento no dispositivo

Perfis, configurações dos dispositivos e medições são salvos em arquivos JSON versionados no ambiente isolado do app. Configurações e registros ficam separados e usam iOS Complete File Protection. Segredos de vinculação e autenticação dos dispositivos ficam no Keychain do sistema.

Os widgets leem um resumo compacto de tendências por meio de um App Group local. O resumo é criptografado com AES-GCM e as chaves são gerenciadas em um Keychain compartilhado. É um compartilhamento entre o app e sua extensão no mesmo dispositivo.

O app não inclui contas, publicidade nem serviços de envio de dados analíticos. Não envia perfis e medições de saúde aos servidores do desenvolvedor nem sincroniza esses dados em tempo real pelo iCloud.

### Transferências controladas pelo usuário

- **Backups do sistema**: arquivos de configurações e medições podem fazer parte dos backups do dispositivo ativados pelo usuário. O sistema cuida do backup e da restauração.
- **Saúde da Apple**: leitura e gravação começam desativadas e exigem configuração e autorização. A leitura é importada apenas para o próprio perfil; a gravação inclui somente novas medições estáveis próprias de dispositivos reais selecionados. Históricos importados, registros manuais, dados simulados e estimativas não são gravados no Saúde. Desligar a sincronização não exclui dados já gravados ou importados.
- **Importação e exportação de arquivos**: iniciadas pelo usuário. O JSON exportado é texto sem criptografia e pode conter perfis, informações dos dispositivos e medições. O usuário escolhe onde salvar e com quem compartilhar.
- **Exportação de diagnósticos**: coletados e exportados pelo usuário, podem conter identificadores dos dispositivos e cargas de dados de medição. Os arquivos originais não devem ser compartilhados publicamente.

Consulte a [política de privacidade](../PrivacyPolicy.md) e o [guia de validação do HealthKit](../AppReviewHealthKit.md) para detalhes e procedimentos de autorização e validação.

## Tecnologia e estrutura do projeto

Requer iOS 17 ou posterior e usa Swift, SwiftUI, Charts, CoreBluetooth, HealthKit, WidgetKit e CryptoKit. Interface, cálculos de domínio, análise de protocolos e serviços do sistema são separados por responsabilidade.

```text
ScaleMe/
├── App/              # Entrada, navegação, inicialização e estado global
├── Core/             # Bases comuns, como localização
├── Domain/           # Modelos de domínio, cálculos e análise de tendências
├── Infrastructure/   # Bluetooth, persistência, saúde, diagnósticos e exportação a widgets
├── Features/         # Início, medição, tendências, dispositivos e configurações
├── Shared/           # Sistema de design e componentes compartilhados
└── Resources/        # Assets, String Catalog e recursos de configuração
ScaleMeWidget/        # Widgets de tendências para a Tela de Início
ScaleMeWidgetShared/  # Contratos de dados e armazenamento compartilhados entre app e widgets
Docs/                # Documentação de implementação e validação
└── readme/           # Traduções completas do README
Tests/Smoke/         # Verificações determinísticas de protocolos, cálculos e idiomas
Tools/               # Ferramentas de desenvolvimento e geração de recursos
```

Consulte [arquitetura e implementação](../Architecture.md) para camadas, transições de estado e o fluxo de Bluetooth.

## Executar o projeto

1. Abra `ScaleMe.xcodeproj` no Xcode 26 ou posterior e selecione o scheme `ScaleMe`.
2. Execute no simulador e ative dados simulados em Configurações → Gerenciamento de dados para explorar perfis, dispositivos, registros e gráficos.
3. Para testar medições Bluetooth reais, configure uma equipe de desenvolvimento, instale em um iPhone e autorize Bluetooth ao procurar dispositivos.
4. Para testar widgets, configure capacidades App Groups e Keychain Sharing correspondentes para o app e a extensão `ScaleMeWidget`.

O simulador e os testes automatizados não substituem a validação de Bluetooth, HealthKit e cada modelo de balança em dispositivos reais. Consulte [desenvolvimento e validação](../Development.md) para requisitos, comandos de compilação e pontos de entrada dos testes.

## Documentação e contribuições

- [Índice da documentação](../README.md)
- [Arquitetura e implementação](../Architecture.md)
- [Matriz de suporte a protocolos](../BluetoothProtocolSupport.md)
- [Dados, sincronização e privacidade](../DataAndPrivacy.md)
- [Desenvolvimento e validação](../Development.md)
- [Convenções de desenvolvimento para agentes](../../AGENTS.md)

O nome chinês é “观我”; o nome em inglês e o do projeto Xcode são “ScaleMe”. O logotipo de referência está em [`Design/Logo/logo.svg`](../../Design/Logo/logo.svg). Marcas de terceiros descrevem compatibilidade ou fontes técnicas e não indicam endosso dos fabricantes.

## Licença

A distribuição do código-fonte do projeto como um todo usa **[GNU GPL v3 ou posterior](../../LICENSE)** (`GPL-3.0-or-later`). Contribuições originais: Copyright (C) 2026 bugwz. Partes de terceiros mantêm seus direitos e licenças originais; consulte o [aviso do projeto](../../NOTICE) e as [licenças e avisos de terceiros](../../LICENSES/README.md).
