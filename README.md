# NFObserver
Um aplicativo escrito em Dart+Flutter para gerenciamento de notas fiscais.

## Motivo
A demanda de notas fiscais na loja variam. As vezes podem vir muitas ou poucas. Conforma a demanda era grande, algumas notas passavam batido, causando algumas divergência com os pagamentos dos boleto.

## Propósito
Este aplicatio tem o objetivo de ajudar a controlar essas divergência, cruzando informações que no final irá nos mostrar se a nota está, em questão de repasse, finalizada.

## Recursos
A lista de alguns recursos que já estão implementadas ou que ainda serão estão abaixo:
- [ ] Filtro por data
  - Permite mostrar os arquivos entre uma data inicial e uma data final
- [x] Filtro por nome e data de criação (Crescente e descrescente).
- [x] Formato de nome do arquivo.
  - Ajuste manual de como é formatado o nome do arquivo salvo para maior facilidade de indentificação de informações pelo nome do arquivo.
- [x] Leitura de informações pelo XML da nota.
  - Ajuda a verificar algumas informações para cruzar com o nomes dos arquivos em PDF da nota.
- [x] Sincronização dos arquivos locais com o servidor IMAP.
  - Verificar se a nota fiscal já foi enviada ao email do financeiro.
- [X] Edição de parametros para icones automaticos de acordo com regras por arquivos.
  - Customizar os icones por critério (Geralmente por conteudo no nome do arquivos).
- [ ] Identifica alterações em nos arquivos nas pasta. (Em progresso).
- [x] Sincronia com servidor IMAP
  - O aplicativo e servidor sincronizados para verificação dos email enviados automaticamente em um intervalo.


>Outros recursos serão planejada e acrescentada à esta lista

### Observações
O aplicativo foi inteiramente desenvolvido para funcionar com um propósito específico e em um ambiente específico, embora há e haverá alguns recursos flexiveis que podem ser adaptados para funcionar em quaisquer ambientes que trabalham com gerenciamento de notas fiscais (Escanear a nota fiscal, salvar o arquivo PDF com o nome do fornecedor e o número da NF).

