import pikepdf, sys
from pikepdf import Name, Dictionary, Array, String
pt_path, en_path, out_path = sys.argv[1:4]
H = 841.91998
# caixas dos botões (pdfplumber: x0, top, x1, bottom) com margem
def rect(x0, top, x1, bottom, mx=6, my=3):
    return Array([x0-mx, H-(bottom+my), x1+mx, H-(top-my)])
import pdfplumber
pos = {}
with pdfplumber.open(pt_path) as pp:
    for w in pp.pages[0].extract_words():
        if w['text'] in ('PT', 'EN') and w['top'] < 80 and w['text'] not in pos:
            pos[w['text']] = (w['x0'], w['top'], w['x1'], w['bottom'])
assert len(pos) == 2, pos
r_pt = rect(*pos['PT'], mx=11, my=4)
r_en = rect(*pos['EN'], mx=11, my=4)

pdf = pikepdf.open(pt_path)
en = pikepdf.open(en_path)
page = pdf.pages[0]
W = float(page.mediabox[2]); HH = float(page.mediabox[3])

oc_pt = pdf.make_indirect(Dictionary(Type=Name.OCG, Name=String('Português (PT)'),
        Usage=Dictionary(Language=Dictionary(Lang=String('pt-PT')))))
oc_en = pdf.make_indirect(Dictionary(Type=Name.OCG, Name=String('English (EN)'),
        Usage=Dictionary(Language=Dictionary(Lang=String('en-GB')))))

# página EN como Form XObject
en_page = pikepdf.Page(en.pages[0])
fx = pdf.copy_foreign(en_page.as_form_xobject())

res = page.obj.Resources
if '/XObject' not in res: res.XObject = Dictionary()
res.XObject['/FxEN'] = fx
if '/Properties' not in res: res.Properties = Dictionary()
res.Properties['/ocPT'] = oc_pt
res.Properties['/ocEN'] = oc_en

C = page.obj.Contents
pt_content = C.read_bytes() if isinstance(C, pikepdf.Stream) else b'\n'.join(c.read_bytes() for c in C)
# EN primeiro; PT por cima com fundo branco opaco (leitores sem camadas mostram só PT)
new = (b'/OC /ocEN BDC q /FxEN Do Q EMC\n'
       b'/OC /ocPT BDC q 1 1 1 rg 0 0 %.3f %.3f re f Q q\n' % (W, HH)
       + pt_content + b'\nQ EMC\n')
page.obj.Contents = pdf.make_stream(new)

pdf.Root.OCProperties = Dictionary(
    OCGs=Array([oc_pt, oc_en]),
    D=Dictionary(Name=String('Língua / Language'), BaseState=Name.ON,
                 ON=Array([oc_pt]), OFF=Array([oc_en]),
                 Order=Array([oc_pt, oc_en]), RBGroups=Array([Array([oc_pt, oc_en])])))

def link(r, on, off):
    return pdf.make_indirect(Dictionary(Type=Name.Annot, Subtype=Name.Link, Rect=r, Border=Array([0,0,0]),
        A=Dictionary(S=Name.SetOCGState, State=Array([Name.ON, on, Name.OFF, off]))))
annots = page.obj.get('/Annots', Array())
annots.append(link(r_pt, oc_pt, oc_en))
annots.append(link(r_en, oc_en, oc_pt))
page.obj.Annots = annots
pdf.Root.Lang = String('pt-PT')
pdf.docinfo['/Title'] = String('Procedimento – Registo de ADF com n.º de PO / Procedure – ADF with PO number')
pdf.docinfo['/Author'] = String('Grupo Naval Angola – Gestão de Projectos Digitais')
pdf.save(out_path)
print('ok')
