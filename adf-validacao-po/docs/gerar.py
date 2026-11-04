# Gera o procedimento ADF / PO em PT e EN (modelo dos procedimentos Naval: folha única estilo Apple).
import os
D = os.path.dirname(os.path.abspath(__file__))

CSS = r"""
@page { size: A4; margin: 0; }
:root {
  --page: #ffffff; --ink: #0b1f3a; --ink-2: #4a5b75; --ink-3: #7c8aa1; --line: #dde4ef;
  --navy: #273777; --blue: #2397d4; --blue-soft: #e6f2fb; --crit: #b42318; --crit-soft: #fdecec; --ok-soft: #e9eef8;
  --f: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", "Segoe UI", Arial, sans-serif;
  --fd: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Helvetica Neue", "Segoe UI", Arial, sans-serif;
  color-scheme: light;
}
* { box-sizing: border-box; }
html, body { background: #fff; margin: 0; padding: 0; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
body { color: var(--ink); font: 12.4px/1.42 var(--f); -webkit-font-smoothing: antialiased; }
.folha { width: 210mm; height: 297mm; overflow: hidden; padding: 10mm 14mm 7mm; display: grid; gap: 11px; align-content: start; }
p { margin: 0; }
.barra { display: flex; justify-content: space-between; align-items: center; }
.marca { display: flex; align-items: center; gap: 10px; }
.marca img { height: 40px; display: block; }
.marca .t1 { font: 700 12px var(--fd); color: var(--navy); letter-spacing: .02em; }
.marca .t2 { font-size: 11px; color: var(--blue); }
.dir { display: flex; align-items: center; gap: 8px; }
.lingua { display: flex; background: var(--blue-soft); border-radius: 999px; padding: 3px; }
.lingua span { font: 600 11.5px var(--f); color: var(--ink-2); padding: 4px 13px; border-radius: 999px; }
.lingua span.on { background: #fff; color: var(--navy); box-shadow: 0 1px 3px rgba(39,55,119,.18); }
.conf { font: 700 10px var(--f); letter-spacing: .08em; color: #fff; background: var(--navy); border-radius: 999px; padding: 5px 11px; }
.topo { display: grid; gap: 6px; }
.eyebrow { font-size: 11px; font-weight: 600; letter-spacing: .08em; text-transform: uppercase; color: var(--blue); }
h1 { margin: 0; font: 700 28px/1.1 var(--fd); letter-spacing: -.025em; color: var(--navy); }
.lead { font-size: 14.2px; color: var(--ink-2); text-align: justify; }
.meta { display: flex; flex-wrap: wrap; gap: 4px 16px; font-size: 10.6px; color: var(--ink-3); border-top: 1px solid var(--line); border-bottom: 1px solid var(--line); padding: 6px 0; }
.meta b { color: var(--ink-2); font-weight: 600; }
h2 { margin: 0 0 8px; font: 600 11px var(--f); letter-spacing: .07em; text-transform: uppercase; color: var(--ink-3); }
.passos { display: grid; grid-template-columns: minmax(0, 1fr) 232px; gap: 18px; align-items: start; }
ol { list-style: none; margin: 0; padding: 0; display: grid; gap: 9px; counter-reset: p; }
li { counter-increment: p; display: grid; grid-template-columns: 26px minmax(0, 1fr); gap: 11px; align-items: start; }
li::before { content: counter(p); width: 26px; height: 26px; border-radius: 50%; background: var(--navy); color: #fff; font: 600 12.5px/26px var(--fd); text-align: center; }
li .t { font: 600 13.6px var(--fd); color: var(--navy); letter-spacing: -.01em; margin-bottom: 1px; }
li p:not(.t) { color: var(--ink-2); text-align: justify; }
.ui { font-weight: 600; color: var(--ink); background: var(--blue-soft); border-radius: 5px; padding: 0 5px; white-space: nowrap; }
code { font: 600 11.4px ui-monospace, "SF Mono", Consolas, monospace; color: var(--navy); background: var(--ok-soft); border-radius: 5px; padding: 0 5px; }
.ecras { display: grid; gap: 8px; }
figure { margin: 0; }
figure img { width: 100%; display: block; border-radius: 9px; border: 1px solid var(--line); }
figcaption { font-size: 10px; color: var(--ink-3); margin-top: 3px; }
.regras { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 9px; }
.regra { background: var(--blue-soft); border-radius: 13px; padding: 10px 13px; display: grid; gap: 2px; }
.regra strong { font: 700 17px/1.15 var(--fd); color: var(--navy); letter-spacing: -.015em; }
.regra > span { font-size: 11.6px; color: var(--ink-2); }
.exemplos { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 6px 18px; margin-top: 9px; font-size: 11.8px; color: var(--ink-2); }
.exemplos p { display: flex; gap: 7px; align-items: baseline; }
.tag { font: 700 9.5px var(--f); letter-spacing: .05em; text-transform: uppercase; border-radius: 999px; padding: 2px 7px; white-space: nowrap; }
.tag.ok { background: var(--ok-soft); color: var(--navy); }
.tag.ko { background: var(--crit-soft); color: var(--crit); }
.ajuda { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 7px 22px; font-size: 12px; color: var(--ink-2); }
.ajuda p { text-align: justify; }
.ajuda b { color: var(--ink); font-weight: 600; }
.resp { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 8px; font-size: 11.4px; color: var(--ink-2); }
.resp div { border-left: 3px solid var(--blue); padding-left: 8px; }
.resp b { display: block; color: var(--navy); font: 600 12px var(--fd); }
.rodape { border-top: 1px solid var(--line); padding-top: 8px; display: flex; justify-content: space-between; gap: 16px; font-size: 10px; color: var(--ink-3); }
"""

T = {
 'pt': dict(
  lang='pt-PT', title='Procedimento – ADF com n.º de PO', t2='Gestão de Projectos Digitais', conf='CONFIDENCIAL',
  eyebrow='Cegid Evolution ERP Primavera · Contas Correntes',
  h1='Adiantamentos a fornecedor com o n.º da PO',
  lead='Todos os Adiantamentos a Fornecedor (ADF) passam a indicar, no campo <span class="ui">Número</span>, a encomenda (PO) a que se referem. O sistema valida o campo ao gravar e não deixa gravar um ADF sem uma PO válida do fornecedor.',
  meta=[('Procedimento',''),('Versão','1.0'),('Data','04-11-2026'),('Código','A atribuir'),('Elaborado por','Gestão de Projectos Digitais'),('Aprovado por','Henrique Fernandes'),('Aplica-se a','17 empresas do grupo')],
  h_passos='Passos',
  passos=[
   ('Abra um novo ADF', 'Em <span class="ui">Contas Correntes</span>, abra <span class="ui">Novos Documentos</span> e escolha o documento <code>ADF</code>.'),
   ('Indique o fornecedor', 'Em <span class="ui">Entidade</span>, seleccione <span class="ui">Fornecedor</span> e escreva o código, por exemplo <code>F000201</code>.'),
   ('Escreva primeiro a PO', 'No campo <span class="ui">Número</span>, apague o número sugerido e escreva a PO no formato <code>TIPO SÉRIE/NÚMERO</code>. Depois da PO, o texto é livre, por exemplo a proforma do fornecedor.'),
   ('Várias PO? Use ponto e vírgula', 'Exemplo: <code>PO 2026/10; PO 2026/11 - Kituco PP2026B/11-12</code>.'),
   ('Complete e grave', 'Preencha as datas, o item de tesouraria e o valor, como habitualmente, e clique em <span class="ui">Gravar</span>.'),
   ('Se aparecer um aviso', 'O ADF <b>não</b> fica gravado. Feche o aviso, corrija o campo <span class="ui">Número</span> e grave de novo.'),
  ],
  fig1='Sem PO no campo Número, o sistema não deixa gravar.', fig2='PO de outro fornecedor: o aviso indica a PO e o fornecedor.',
  h_regras='O campo Número tem de ter',
  regras=[('PO no início','tipos PO, POL, POS, POM, POI ou ECF'),('PO válida','existe nesta empresa e não está anulada'),('Mesmo fornecedor','a PO é do fornecedor do ADF')],
  exemplos=[('ok','Aceite','<code>PO 2026/756 - Natighe PP 2026A/89</code>'),('ko','Recusado','<code>Pag.Natighe PP 2026A/89</code> (sem PO)'),
            ('ok','Aceite','<code>PO 2026/10; POL 2026/12</code>'),('ko','Recusado','<code>Natighe - PO 2026/756</code> (PO no fim)')],
  h_ajuda='Se aparecer um aviso',
  ajuda=[('«Tem de começar pelo n.º da PO»','escreva a PO no início do campo; a referência do fornecedor (PP, ORC, FT) fica depois.'),
         ('«Não existe nesta empresa»','confirme o n.º e o tipo da PO com Compras e se está na empresa certa.'),
         ('«Está anulada»','peça a Compras o n.º da PO que substituiu a anulada.'),
         ('«Pertence ao fornecedor X e não a Y»','corrija o fornecedor do ADF ou a PO indicada.')],
  h_resp='Responsabilidades',
  resp=[('Compras','Regista e aprova a PO antes do pedido de adiantamento.'),('Tesouraria','Regista o ADF com a PO correcta.'),
        ('Finanças','Revê todos os meses a lista de ADF sem PO válida.'),('Projectos Digitais','Suporte e manutenção da validação.')],
  rod1='Documento confidencial – uso interno do Grupo Naval Angola. Proibida a cópia ou divulgação sem autorização prévia.',
  rod2='Grupo Naval Angola · 04-11-2026 · v1.0'),
 'en': dict(
  lang='en-GB', title='Procedure – ADF with PO number', t2='Digital Projects Management', conf='CONFIDENTIAL',
  eyebrow='Cegid Evolution ERP Primavera · Current Accounts',
  h1='Supplier advance payments with the PO number',
  lead='Every Supplier Advance Payment (ADF) must now state, in the <span class="ui">Number</span> field, the purchase order (PO) it relates to. The system checks the field on saving and will not save an ADF without a valid PO from the supplier.',
  meta=[('Procedure',''),('Version','1.0'),('Date','04-11-2026'),('Code','To be assigned'),('Prepared by','Digital Projects Management'),('Approved by','Henrique Fernandes'),('Applies to','17 group companies')],
  h_passos='Steps',
  passos=[
   ('Open a new ADF', 'In <span class="ui">Current Accounts</span>, open <span class="ui">New Documents</span> and select the <code>ADF</code> document.'),
   ('Enter the supplier', 'In <span class="ui">Entity</span>, select <span class="ui">Supplier</span> and type the code, for example <code>F000201</code>.'),
   ('Type the PO first', 'In the <span class="ui">Number</span> field, delete the suggested number and type the PO in the format <code>TYPE SERIES/NUMBER</code>. Any text may follow the PO, for example the supplier’s pro forma.'),
   ('Several POs? Use a semicolon', 'Example: <code>PO 2026/10; PO 2026/11 - Kituco PP2026B/11-12</code>.'),
   ('Complete and save', 'Fill in the dates, the treasury item and the amount as usual, and click <span class="ui">Save</span>.'),
   ('If a warning appears', 'The ADF is <b>not</b> saved. Close the warning, correct the <span class="ui">Number</span> field and save again.'),
  ],
  fig1='With no PO in the Number field, the system does not save.', fig2='PO from another supplier: the warning shows the PO and the supplier.',
  h_regras='The Number field must have',
  regras=[('PO at the start','types PO, POL, POS, POM, POI or ECF'),('A valid PO','exists in this company and is not cancelled'),('Same supplier','the PO belongs to the ADF supplier')],
  exemplos=[('ok','Accepted','<code>PO 2026/756 - Natighe PP 2026A/89</code>'),('ko','Rejected','<code>Pag.Natighe PP 2026A/89</code> (no PO)'),
            ('ok','Accepted','<code>PO 2026/10; POL 2026/12</code>'),('ko','Rejected','<code>Natighe - PO 2026/756</code> (PO at the end)')],
  h_ajuda='If a warning appears',
  ajuda=[('“Must start with the PO number”','type the PO at the start of the field; the supplier reference (PP, ORC, FT) goes after it.'),
         ('“Does not exist in this company”','check the PO number and type with Procurement, and that you are in the right company.'),
         ('“Is cancelled”','ask Procurement for the number of the PO that replaced the cancelled one.'),
         ('“Belongs to supplier X, not Y”','correct the ADF supplier or the PO entered.')],
  h_resp='Responsibilities',
  resp=[('Procurement','Creates and approves the PO before the advance is requested.'),('Treasury','Records the ADF with the correct PO.'),
        ('Finance','Reviews the list of ADFs without a valid PO every month.'),('Digital Projects','Support and maintenance of the validation.')],
  rod1='Confidential document – internal use of Grupo Naval Angola. Copying or disclosure without prior authorisation is prohibited.',
  rod2='Grupo Naval Angola · 04-11-2026 · v1.0'),
}

def pagina(l):
    t = T[l]
    sel = ''.join('<span class="%s">%s</span>' % ('on' if x == l else '', x.upper()) for x in ('pt', 'en'))
    meta = ''.join('<span>%s</span>' % (('<b>%s</b>' % k) if not v else ('%s: <b>%s</b>' % (k, v))) for k, v in t['meta'])
    passos = ''.join('<li><div><p class="t">%s</p><p>%s</p></div></li>' % p for p in t['passos'])
    regras = ''.join('<div class="regra"><strong>%s</strong><span>%s</span></div>' % r for r in t['regras'])
    ex = ''.join('<p><span class="tag %s">%s</span><span>%s</span></p>' % e for e in t['exemplos'])
    ajuda = ''.join('<p><b>%s:</b> %s</p>' % a for a in t['ajuda'])
    resp = ''.join('<div><b>%s</b>%s</div>' % r for r in t['resp'])
    return f'''<!doctype html><html lang="{t['lang']}"><head><meta charset="utf-8"><title>{t['title']}</title><style>{CSS}</style></head><body>
<main class="folha">
  <div class="barra">
    <div class="marca"><img src="naval-logo-claro.png" alt="Naval"><div><div class="t1">GRUPO NAVAL ANGOLA</div><div class="t2">{t['t2']}</div></div></div>
    <div class="dir"><div class="lingua">{sel}</div><span class="conf">{t['conf']}</span></div>
  </div>
  <div class="topo">
    <p class="eyebrow">{t['eyebrow']}</p>
    <h1>{t['h1']}</h1>
    <p class="lead">{t['lead']}</p>
  </div>
  <div class="meta">{meta}</div>
  <section>
    <h2>{t['h_passos']}</h2>
    <div class="passos">
      <ol>{passos}</ol>
      <div class="ecras">
        <figure><img src="fig1.png" alt=""><figcaption>{t['fig1']}</figcaption></figure>
        <figure><img src="fig2.png" alt=""><figcaption>{t['fig2']}</figcaption></figure>
      </div>
    </div>
  </section>
  <section>
    <h2>{t['h_regras']}</h2>
    <div class="regras">{regras}</div>
    <div class="exemplos">{ex}</div>
  </section>
  <section>
    <h2>{t['h_ajuda']}</h2>
    <div class="ajuda">{ajuda}</div>
  </section>
  <section>
    <h2>{t['h_resp']}</h2>
    <div class="resp">{resp}</div>
  </section>
  <div class="rodape"><span>{t['rod1']}</span><span>{t['rod2']}</span></div>
</main></body></html>'''

for l in ('pt', 'en'):
    open(os.path.join(D, l + '.html'), 'w', encoding='utf-8').write(pagina(l))
print('ok')
