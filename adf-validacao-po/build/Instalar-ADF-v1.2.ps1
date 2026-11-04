# ============================================================
#  Extensão ADF / PO – versão 1.2 (F4 com selecção de várias PO)
#  Cria os ficheiros em C:\Naval\Extensoes e compila.
#  Grupo Naval Angola – Gestão de Projectos Digitais. CONFIDENCIAL.
#  Executar no servidor, com o Primavera fechado:
#    powershell -ExecutionPolicy Bypass -File .\Instalar-ADF-v1.2.ps1
# ============================================================
$Pasta = "C:\Naval\Extensoes"
if (-not (Test-Path $Pasta)) { New-Item -ItemType Directory -Path $Pasta | Out-Null }
$f1 = @'
// ============================================================
//  Naval.Extensibility.ContasCorrentes
//  Validação do n.º da PO no campo "Número do Documento" dos ADF
//  e selecção das PO do fornecedor com F4.
//  Grupo Naval Angola – Gestão de Projectos Digitais. CONFIDENCIAL.
//
//  1.0.0 (04/11/2026) Versão inicial: validação de uma ou mais PO.
//  1.1.0 (04/11/2026) Mensagens num só parágrafo; método de aviso actual.
//  1.2.0 (04/11/2026) F4 no campo Número abre a lista das PO do
//                     fornecedor, com selecção de várias linhas; F4
//                     repetido acrescenta PO. Shift+F4 em qualquer campo
//                     do ADF abre a mesma lista.
// ============================================================
using System;
using System.Collections.Generic;
using System.Data;
using System.Reflection;
using System.Text.RegularExpressions;
using System.Windows.Forms;
using Primavera.Extensibility.BusinessEntities.ExtensibilityService.EventArgs;
using Primavera.Extensibility.PayablesReceivables.Editors;
using StdPlatBS100;

[assembly: AssemblyTitle("Naval – Validação e selecção de PO nos ADF")]
[assembly: AssemblyDescription("Obriga a indicar PO válidas do fornecedor no Número do Documento dos ADF e permite escolhê-las com F4.")]
[assembly: AssemblyCompany("Grupo Naval Angola – Gestão de Projectos Digitais")]
[assembly: AssemblyProduct("Naval.Extensibility.ContasCorrentes")]
[assembly: AssemblyCopyright("Grupo Naval Angola 2026 – Confidencial")]
[assembly: AssemblyVersion("1.2.0.0")]
[assembly: AssemblyFileVersion("1.2.0.0")]

namespace Naval.Extensibility.ContasCorrentes
{
    public class UiEditorPendentes : EditorPendentes
    {
        private const string TipoDocADF = "ADF";
        private const int TeclaF4 = 115;
        private const int ShiftMask = 1;
        private const int CtrlMask = 2;
        private const string TiposPO = "'PO','POL','POS','POM','POI','ECF'";

        internal static readonly Regex RxInicio = new Regex(
            @"^\s*(?:POL|POS|POM|POI|ECF|PO)\s+[A-Z0-9]+\s*/\s*\d+(?:\s*[;,]\s*(?:POL|POS|POM|POI|ECF|PO)\s+[A-Z0-9]+\s*/\s*\d+)*",
            RegexOptions.IgnoreCase | RegexOptions.Compiled);

        internal static readonly Regex RxPO = new Regex(
            @"(?<tipo>POL|POS|POM|POI|ECF|PO)\s+(?<serie>[A-Z0-9]+)\s*/\s*(?<num>\d+)",
            RegexOptions.IgnoreCase | RegexOptions.Compiled);

        // Últimos valores identificados no editor (o documento pode ainda não os ter).
        private string _tipoDoc = string.Empty;
        private string _tipoEntidade = string.Empty;
        private string _entidade = string.Empty;
        private int _tamanhoNumDoc = -1;

        // ---------------------------------------------------------------
        //  Eventos do editor
        // ---------------------------------------------------------------
        public override void TipoDocumentoIdentificado(string Tipo, ref bool Cancel, ExtensibilityEventArgs e)
        {
            base.TipoDocumentoIdentificado(Tipo, ref Cancel, e);
            _tipoDoc = Tipo ?? string.Empty;
        }

        public override void EntidadeIdentificada(string TipoEntidade, string Entidade, ref bool Cancel, ExtensibilityEventArgs e)
        {
            base.EntidadeIdentificada(TipoEntidade, Entidade, ref Cancel, e);
            _tipoEntidade = TipoEntidade ?? string.Empty;
            _entidade = Entidade ?? string.Empty;
        }

        public override void TeclaPressionada(int KeyCode, int Shift, ExtensibilityEventArgs e)
        {
            base.TeclaPressionada(KeyCode, Shift, e);
            if (KeyCode != TeclaF4) return;

            try
            {
                if (!EADF()) return;

                Control alvo = ControloNumero();
                bool shiftF4 = (Shift & ShiftMask) != 0 && (Shift & CtrlMask) == 0;

                // F4 só no campo Número; Shift+F4 em qualquer campo do ADF.
                if (alvo == null && !shiftF4) return;

                AbrirSeleccao(alvo);
            }
            catch (Exception ex)
            {
                Aviso("Não foi possível abrir a lista de PO: " + ex.Message);
            }
        }

        public override void AntesDeGravar(ref bool Cancel, ExtensibilityEventArgs e)
        {
            base.AntesDeGravar(ref Cancel, e);
            if (Cancel) return;

            var doc = this.DocumentoPendente;
            if (doc == null) return;

            if (!string.Equals(doc.Tipodoc, TipoDocADF, StringComparison.OrdinalIgnoreCase)) return;
            if (!string.Equals(doc.TipoEntidade, "F", StringComparison.OrdinalIgnoreCase)) return;

            string numDoc = (doc.NumDoc ?? string.Empty).Trim().ToUpperInvariant();
            string fornecedor = doc.Entidade ?? string.Empty;

            Match inicio = RxInicio.Match(numDoc);
            if (!inicio.Success)
            {
                Bloquear(ref Cancel,
                    "O campo 'Número do Documento' tem de começar pelo n.º da PO deste fornecedor. " +
                    "Carregue em F4 no campo Número para escolher a(s) PO, ou escreva-a(s), por exemplo: PO 2026/756 - Natighe PP 2026A/89. " +
                    "Para várias PO, separe-as com ponto e vírgula: PO 2026/10; PO 2026/11.");
                return;
            }

            var erros = new List<string>();
            var vistas = new HashSet<string>();

            foreach (Match m in RxPO.Matches(inicio.Value))
            {
                string tipo = m.Groups["tipo"].Value.ToUpperInvariant();
                string serie = m.Groups["serie"].Value.ToUpperInvariant();
                string num = m.Groups["num"].Value;
                string po = tipo + " " + serie + "/" + num;

                if (!vistas.Add(po)) continue;

                string estado = ValidarPO(tipo, serie, num, fornecedor);
                if (estado != null) erros.Add(po + " " + estado);
            }

            if (erros.Count > 0)
            {
                Bloquear(ref Cancel,
                    "Não é possível gravar o adiantamento: " +
                    string.Join(" | ", erros.ToArray()) + ". " +
                    "Corrija o n.º da PO no campo 'Número do Documento' (F4 mostra as PO do fornecedor).");
            }
        }

        // ---------------------------------------------------------------
        //  Selecção com F4
        // ---------------------------------------------------------------
        private void AbrirSeleccao(Control alvo)
        {
            var doc = this.DocumentoPendente;

            string tipoEnt = (doc != null && !string.IsNullOrEmpty(doc.TipoEntidade)) ? doc.TipoEntidade : _tipoEntidade;
            string fornecedor = (doc != null && !string.IsNullOrEmpty(doc.Entidade)) ? doc.Entidade : _entidade;

            if (!string.Equals(tipoEnt, "F", StringComparison.OrdinalIgnoreCase) || string.IsNullOrEmpty(fornecedor))
            {
                Aviso("Indique primeiro o fornecedor em 'Entidade' e depois carregue em F4 no campo Número.");
                return;
            }

            string actual = alvo != null ? (alvo.Text ?? string.Empty) : (doc != null ? (doc.NumDoc ?? string.Empty) : string.Empty);

            // PO já escritas no início do campo e o texto livre que se segue
            var existentes = new List<string>();
            string resto = actual;
            Match inicio = RxInicio.Match(actual.ToUpperInvariant());
            if (inicio.Success)
            {
                foreach (Match m in RxPO.Matches(inicio.Value))
                {
                    string po = m.Groups["tipo"].Value.ToUpperInvariant() + " " +
                                m.Groups["serie"].Value.ToUpperInvariant() + "/" + m.Groups["num"].Value;
                    if (!existentes.Contains(po)) existentes.Add(po);
                }
                resto = actual.Substring(inicio.Length);
            }
            else if (EsperaNumeroSistema(actual))
            {
                resto = string.Empty;   // número sugerido pelo sistema: substituído pelas PO
            }

            DataTable tabela = CarregarPO(fornecedor);
            if (tabela.Rows.Count == 0)
            {
                Aviso("O fornecedor " + fornecedor + " não tem PO registadas nesta empresa. Peça a Compras que registe a PO antes do adiantamento.");
                return;
            }

            string nome = NomeFornecedor(fornecedor);

            using (var f = new FrmSeleccaoPO(fornecedor, nome, tabela, existentes))
            {
                IWin32Window dono = Form.ActiveForm;
                if (f.ShowDialog(dono) != DialogResult.OK) return;

                // PO marcadas: primeiro as que já estavam (pela ordem original), depois as novas
                var finais = new List<string>();
                foreach (string po in existentes) if (f.Seleccionadas.Contains(po)) finais.Add(po);
                foreach (string po in f.Seleccionadas) if (!finais.Contains(po)) finais.Add(po);

                string novo = string.Join("; ", finais.ToArray());
                string restoLimpo = resto.Trim();
                if (restoLimpo.Length > 0)
                {
                    if (restoLimpo.StartsWith(";") || restoLimpo.StartsWith(",")) restoLimpo = restoLimpo.Substring(1).Trim();
                    if (restoLimpo.Length > 0)
                        novo = finais.Count > 0
                            ? novo + (restoLimpo.StartsWith("-") ? " " : " - ") + restoLimpo
                            : restoLimpo;
                }

                int max = TamanhoNumDoc();
                if (max > 0 && novo.Length > max)
                {
                    Aviso("O texto ficaria com " + novo.Length + " caracteres e o campo Número aceita no máximo " + max +
                          ". Reduza o texto livre depois das PO ou registe um ADF por grupo de PO.");
                    return;
                }

                EscreverNumero(alvo, novo);
            }
        }

        private DataTable CarregarPO(string fornecedor)
        {
            var t = new DataTable();
            t.Columns.Add("Sel", typeof(bool));
            t.Columns.Add("PO", typeof(string));
            t.Columns.Add("Data", typeof(DateTime));
            t.Columns.Add("RefFornecedor", typeof(string));
            t.Columns.Add("Valor", typeof(decimal));
            t.Columns.Add("Moeda", typeof(string));
            t.Columns.Add("Estado", typeof(string));

            string sql =
                "SELECT c.TipoDoc + ' ' + c.Serie + '/' + CAST(c.NumDoc AS VARCHAR(20)) AS PO, " +
                "       c.DataDoc, ISNULL(c.NumDocExterno, '') AS RefFornecedor, ISNULL(c.Moeda, '') AS Moeda, " +
                "       CAST(ISNULL((SELECT SUM(ABS(l.Quantidade * l.PrecUnit * (1 - ISNULL(l.Desconto1, 0) / 100.0))) " +
                "                    FROM LinhasCompras l WHERE l.IdCabecCompras = c.Id AND l.Artigo IS NOT NULL), 0) AS DECIMAL(18,2)) AS Valor, " +
                "       ISNULL(cs.Fechado, 0) AS Fechado " +
                "FROM CabecCompras c " +
                "INNER JOIN CabecComprasStatus cs ON cs.IdCabecCompras = c.Id " +
                "WHERE c.TipoEntidade = 'F' AND c.Entidade = '" + fornecedor.Replace("'", "''") + "' " +
                "  AND c.TipoDoc IN (" + TiposPO + ") " +
                "  AND ISNULL(cs.Anulado, 0) = 0 " +
                "ORDER BY ISNULL(cs.Fechado, 0), c.DataDoc DESC, c.NumDoc DESC";

            var lista = BSO.Consulta(sql);
            if (lista == null || lista.Vazia()) return t;

            while (!lista.NoFim())
            {
                DateTime data;
                object v = lista.Valor("DataDoc");
                data = (v == null || v is DBNull) ? DateTime.MinValue : Convert.ToDateTime(v);

                t.Rows.Add(false,
                    Convert.ToString(lista.Valor("PO")),
                    data,
                    Convert.ToString(lista.Valor("RefFornecedor")),
                    Convert.ToDecimal(lista.Valor("Valor")),
                    Convert.ToString(lista.Valor("Moeda")),
                    Convert.ToInt32(lista.Valor("Fechado")) != 0 ? "Fechada" : "Aberta");
                lista.Seguinte();
            }
            return t;
        }

        private string NomeFornecedor(string fornecedor)
        {
            try
            {
                var l = BSO.Consulta("SELECT Nome FROM Fornecedores WHERE Fornecedor = '" + fornecedor.Replace("'", "''") + "'");
                if (l != null && !l.Vazia()) return Convert.ToString(l.Valor("Nome"));
            }
            catch { }
            return string.Empty;
        }

        private int TamanhoNumDoc()
        {
            if (_tamanhoNumDoc >= 0) return _tamanhoNumDoc;
            _tamanhoNumDoc = 0;
            try
            {
                var l = BSO.Consulta("SELECT CHARACTER_MAXIMUM_LENGTH AS L FROM INFORMATION_SCHEMA.COLUMNS " +
                                     "WHERE TABLE_NAME = 'Historico' AND COLUMN_NAME = 'NumDoc'");
                if (l != null && !l.Vazia()) _tamanhoNumDoc = Convert.ToInt32(l.Valor("L"));
            }
            catch { }
            return _tamanhoNumDoc;
        }

        private void EscreverNumero(Control alvo, string valor)
        {
            if (alvo != null)
            {
                alvo.Text = valor;
                alvo.Focus();
            }
            try
            {
                var doc = this.DocumentoPendente;
                if (doc != null) doc.NumDoc = valor;
            }
            catch { }
        }

        // ---------------------------------------------------------------
        //  Auxiliares
        // ---------------------------------------------------------------
        private bool EADF()
        {
            var doc = this.DocumentoPendente;
            string tipo = (doc != null && !string.IsNullOrEmpty(doc.Tipodoc)) ? doc.Tipodoc : _tipoDoc;
            return string.Equals(tipo, TipoDocADF, StringComparison.OrdinalIgnoreCase);
        }

        private static bool EsperaNumeroSistema(string texto)
        {
            string t = (texto ?? string.Empty).Trim();
            if (t.Length == 0) return true;
            foreach (char c in t) if (!char.IsDigit(c)) return false;
            return true;
        }

        /// <summary>Devolve o controlo do campo Número se for ele que tem o foco; caso contrário, null.</summary>
        private Control ControloNumero()
        {
            Control c = ControloComFoco();
            if (c == null) return null;

            // Editores compostos: o foco pode estar na caixa interior; o nome está no controlo exterior.
            for (Control x = c; x != null; x = x.Parent)
            {
                string n = (x.Name ?? string.Empty).ToLowerInvariant();
                if (n.Contains("numdocext") || n.Contains("numdocint")) return null;
                if (n.Contains("numdoc") || n.Contains("numero")) return x;
                if (x is Form) break;
            }

            // Recurso: o texto do controlo coincide com o Número actual do documento.
            var doc = this.DocumentoPendente;
            if (doc != null && !string.IsNullOrEmpty(doc.NumDoc) &&
                string.Equals((c.Text ?? string.Empty).Trim(), doc.NumDoc.Trim(), StringComparison.OrdinalIgnoreCase))
                return c;

            return null;
        }

        private static Control ControloComFoco()
        {
            Control c = Form.ActiveForm;
            int guarda = 0;
            while (c != null && guarda++ < 50)
            {
                Form f = c as Form;
                if (f != null && f.IsMdiContainer && f.ActiveMdiChild != null) { c = f.ActiveMdiChild; continue; }
                ContainerControl cc = c as ContainerControl;
                if (cc != null && cc.ActiveControl != null && cc.ActiveControl != c) { c = cc.ActiveControl; continue; }
                break;
            }
            return c;
        }

        private string ValidarPO(string tipo, string serie, string num, string fornecedor)
        {
            string sql =
                "SELECT c.Entidade, ISNULL(cs.Anulado, 0) AS Anulado " +
                "FROM CabecCompras c " +
                "INNER JOIN CabecComprasStatus cs ON cs.IdCabecCompras = c.Id " +
                "WHERE c.TipoDoc = '" + tipo + "' AND c.Serie = '" + serie + "' AND c.NumDoc = " + num;

            var lista = BSO.Consulta(sql);

            if (lista == null || lista.Vazia())
                return "não existe nesta empresa";

            string entidadePO = Convert.ToString(lista.Valor("Entidade"));
            bool anulada = Convert.ToInt32(lista.Valor("Anulado")) != 0;

            if (anulada)
                return "está anulada";

            if (!string.Equals(entidadePO, fornecedor, StringComparison.OrdinalIgnoreCase))
                return "pertence ao fornecedor " + entidadePO + " e não a " + fornecedor;

            return null;
        }

        private void Bloquear(ref bool Cancel, string mensagem)
        {
            Cancel = true;
            Aviso(mensagem);
        }

        private void Aviso(string mensagem)
        {
#if NOVA_API
            PSO.Dialogos.MostraMensagem(StdBSTipos.TipoMsg.PRI_SimplesOk, mensagem, StdBSTipos.IconId.PRI_Exclama);
#else
#pragma warning disable 612, 618
            PSO.Dialogos.MostraAviso(mensagem, StdBSTipos.IconId.PRI_Exclama);
#pragma warning restore 612, 618
#endif
        }
    }
}
'@
Set-Content -Path (Join-Path $Pasta "UiEditorPendentes.cs") -Value $f1 -Encoding UTF8
$f2 = @'
// ============================================================
//  Janela de selecção de PO do fornecedor (várias linhas).
//  Grupo Naval Angola – Gestão de Projectos Digitais. CONFIDENCIAL.
// ============================================================
using System;
using System.Collections.Generic;
using System.Data;
using System.Drawing;
using System.Windows.Forms;

namespace Naval.Extensibility.ContasCorrentes
{
    internal sealed class FrmSeleccaoPO : Form
    {
        private static readonly Color Navy = Color.FromArgb(0x27, 0x37, 0x77);
        private static readonly Color AzulSuave = Color.FromArgb(0xE6, 0xF2, 0xFB);

        private readonly DataTable _tabela;
        private readonly DataView _vista;
        private readonly List<string> _foraDaLista = new List<string>();
        private readonly DataGridView _grelha = new DataGridView();
        private readonly TextBox _pesquisa = new TextBox();
        private readonly Label _contador = new Label();

        /// <summary>PO marcadas ao confirmar (inclui PO já escritas que não aparecem na lista).</summary>
        public List<string> Seleccionadas { get; private set; }

        public FrmSeleccaoPO(string fornecedor, string nome, DataTable tabela, List<string> existentes)
        {
            _tabela = tabela;
            Seleccionadas = new List<string>();

            // Marca as PO que já estão no campo; guarda as que não aparecem na lista
            foreach (string po in existentes)
            {
                bool encontrada = false;
                foreach (DataRow r in _tabela.Rows)
                {
                    if (string.Equals(Convert.ToString(r["PO"]), po, StringComparison.OrdinalIgnoreCase))
                    {
                        r["Sel"] = true; encontrada = true; break;
                    }
                }
                if (!encontrada) _foraDaLista.Add(po);
            }

            _vista = new DataView(_tabela);

            // Janela
            Text = "Seleccionar PO do fornecedor";
            StartPosition = FormStartPosition.CenterParent;
            FormBorderStyle = FormBorderStyle.Sizable;
            MinimizeBox = false; MaximizeBox = true; ShowInTaskbar = false;
            Size = new Size(860, 520);
            MinimumSize = new Size(640, 380);
            Font = new Font("Segoe UI", 9F);
            BackColor = Color.White;
            KeyPreview = true;

            // Cabeçalho
            var cab = new Panel { Dock = DockStyle.Top, Height = 58, BackColor = Navy, Padding = new Padding(14, 8, 14, 8) };
            var titulo = new Label
            {
                Text = "PO do fornecedor " + fornecedor + (string.IsNullOrEmpty(nome) ? "" : " – " + nome),
                ForeColor = Color.White, Font = new Font("Segoe UI Semibold", 11F), AutoSize = false,
                Dock = DockStyle.Top, Height = 22
            };
            var sub = new Label
            {
                Text = "Marque uma ou mais PO e clique em Confirmar. As PO já indicadas no campo Número aparecem marcadas.",
                ForeColor = Color.FromArgb(0xD6, 0xE6, 0xF5), AutoSize = false, Dock = DockStyle.Top, Height = 20
            };
            cab.Controls.Add(sub); cab.Controls.Add(titulo);

            // Barra de pesquisa
            var barra = new Panel { Dock = DockStyle.Top, Height = 40, Padding = new Padding(14, 8, 14, 6), BackColor = AzulSuave };
            var lblPesq = new Label { Text = "Procurar:", AutoSize = true, Dock = DockStyle.Left, Padding = new Padding(0, 4, 6, 0) };
            _pesquisa.Dock = DockStyle.Left; _pesquisa.Width = 260;
            _pesquisa.TextChanged += delegate { Filtrar(); };
            var btnTodas = new LinkLabel { Text = "Marcar visíveis", AutoSize = true, Dock = DockStyle.Right, Padding = new Padding(10, 4, 0, 0), LinkColor = Navy };
            var btnNenhuma = new LinkLabel { Text = "Desmarcar todas", AutoSize = true, Dock = DockStyle.Right, Padding = new Padding(10, 4, 0, 0), LinkColor = Navy };
            btnTodas.LinkClicked += delegate { MarcarVisiveis(true); };
            btnNenhuma.LinkClicked += delegate { foreach (DataRow r in _tabela.Rows) r["Sel"] = false; ActualizarContador(); };
            barra.Controls.Add(_pesquisa); barra.Controls.Add(lblPesq); barra.Controls.Add(btnTodas); barra.Controls.Add(btnNenhuma);

            // Grelha
            _grelha.Dock = DockStyle.Fill;
            _grelha.AutoGenerateColumns = false;
            _grelha.AllowUserToAddRows = false; _grelha.AllowUserToDeleteRows = false; _grelha.AllowUserToResizeRows = false;
            _grelha.RowHeadersVisible = false;
            _grelha.SelectionMode = DataGridViewSelectionMode.FullRowSelect;
            _grelha.MultiSelect = true;
            _grelha.BackgroundColor = Color.White;
            _grelha.BorderStyle = BorderStyle.None;
            _grelha.EnableHeadersVisualStyles = false;
            _grelha.ColumnHeadersDefaultCellStyle.BackColor = Color.FromArgb(0xF3, 0xF6, 0xFA);
            _grelha.ColumnHeadersDefaultCellStyle.ForeColor = Navy;
            _grelha.ColumnHeadersDefaultCellStyle.Font = new Font("Segoe UI Semibold", 9F);
            _grelha.DefaultCellStyle.SelectionBackColor = AzulSuave;
            _grelha.DefaultCellStyle.SelectionForeColor = Color.Black;
            _grelha.ColumnHeadersHeight = 30;
            _grelha.RowTemplate.Height = 26;

            _grelha.Columns.Add(new DataGridViewCheckBoxColumn { DataPropertyName = "Sel", HeaderText = "", Width = 34 });
            _grelha.Columns.Add(Coluna("PO", "PO", 120, null, DataGridViewContentAlignment.MiddleLeft));
            _grelha.Columns.Add(Coluna("Data", "Data", 90, "dd-MM-yyyy", DataGridViewContentAlignment.MiddleLeft));
            _grelha.Columns.Add(Coluna("RefFornecedor", "Ref. do fornecedor", 220, null, DataGridViewContentAlignment.MiddleLeft));
            _grelha.Columns.Add(Coluna("Valor", "Valor (s/ IVA)", 130, "#,##0.00", DataGridViewContentAlignment.MiddleRight));
            _grelha.Columns.Add(Coluna("Moeda", "Moeda", 60, null, DataGridViewContentAlignment.MiddleCenter));
            _grelha.Columns.Add(Coluna("Estado", "Estado", 80, null, DataGridViewContentAlignment.MiddleCenter));
            for (int i = 1; i < _grelha.Columns.Count; i++) _grelha.Columns[i].ReadOnly = true;
            _grelha.Columns[3].AutoSizeMode = DataGridViewAutoSizeColumnMode.Fill;

            _grelha.DataSource = _vista;
            _grelha.CellContentClick += delegate(object s, DataGridViewCellEventArgs a)
            {
                if (a.ColumnIndex == 0 && a.RowIndex >= 0) { _grelha.CommitEdit(DataGridViewDataErrorContexts.Commit); ActualizarContador(); }
            };
            _grelha.CellDoubleClick += delegate(object s, DataGridViewCellEventArgs a)
            {
                if (a.RowIndex >= 0 && a.ColumnIndex > 0) { Alternar(a.RowIndex); }
            };
            _grelha.KeyDown += delegate(object s, KeyEventArgs a)
            {
                if (a.KeyCode == Keys.Space)
                {
                    foreach (DataGridViewRow r in _grelha.SelectedRows) Alternar(r.Index);
                    a.Handled = true;
                }
            };

            // Rodapé
            var rod = new Panel { Dock = DockStyle.Bottom, Height = 50, Padding = new Padding(14, 10, 14, 10) };
            var btnOk = new Button { Text = "Confirmar", Width = 110, Dock = DockStyle.Right, BackColor = Navy, ForeColor = Color.White, FlatStyle = FlatStyle.Flat };
            btnOk.FlatAppearance.BorderSize = 0;
            var espaco = new Panel { Width = 8, Dock = DockStyle.Right };
            var btnCancel = new Button { Text = "Cancelar", Width = 100, Dock = DockStyle.Right, DialogResult = DialogResult.Cancel, FlatStyle = FlatStyle.Flat };
            _contador.Dock = DockStyle.Fill; _contador.TextAlign = ContentAlignment.MiddleLeft; _contador.ForeColor = Navy;
            btnOk.Click += delegate { Confirmar(); };
            rod.Controls.Add(_contador); rod.Controls.Add(btnOk); rod.Controls.Add(espaco); rod.Controls.Add(btnCancel);

            Controls.Add(_grelha); Controls.Add(barra); Controls.Add(cab); Controls.Add(rod);
            AcceptButton = btnOk; CancelButton = btnCancel;

            KeyDown += delegate(object s, KeyEventArgs a)
            {
                if (a.KeyCode == Keys.F3 || (a.Control && a.KeyCode == Keys.F)) { _pesquisa.Focus(); a.Handled = true; }
            };
            Shown += delegate { _grelha.Focus(); };
            ActualizarContador();
        }

        private static DataGridViewTextBoxColumn Coluna(string campo, string titulo, int largura, string formato, DataGridViewContentAlignment alinhamento)
        {
            var c = new DataGridViewTextBoxColumn { DataPropertyName = campo, HeaderText = titulo, Width = largura };
            if (formato != null) c.DefaultCellStyle.Format = formato;
            c.DefaultCellStyle.Alignment = alinhamento;
            c.HeaderCell.Style.Alignment = alinhamento;
            return c;
        }

        private void Alternar(int indiceVista)
        {
            if (indiceVista < 0 || indiceVista >= _vista.Count) return;
            DataRowView r = _vista[indiceVista];
            r["Sel"] = !(r["Sel"] is bool && (bool)r["Sel"]);
            ActualizarContador();
        }

        private void MarcarVisiveis(bool valor)
        {
            foreach (DataRowView r in _vista) r["Sel"] = valor;
            ActualizarContador();
        }

        private void Filtrar()
        {
            string t = (_pesquisa.Text ?? string.Empty).Trim().Replace("'", "''").Replace("[", "[[]").Replace("%", "[%]").Replace("*", "[*]");
            _vista.RowFilter = t.Length == 0 ? string.Empty
                : "PO LIKE '%" + t + "%' OR RefFornecedor LIKE '%" + t + "%' OR Estado LIKE '%" + t + "%'";
        }

        private int Marcadas()
        {
            int n = 0;
            foreach (DataRow r in _tabela.Rows) if (r["Sel"] is bool && (bool)r["Sel"]) n++;
            return n;
        }

        private void ActualizarContador()
        {
            int n = Marcadas() + _foraDaLista.Count;
            _contador.Text = n == 0 ? "Nenhuma PO marcada" : (n == 1 ? "1 PO marcada" : n + " PO marcadas");
        }

        private void Confirmar()
        {
            _grelha.EndEdit();
            Seleccionadas = new List<string>(_foraDaLista);
            foreach (DataRow r in _tabela.Rows)
                if (r["Sel"] is bool && (bool)r["Sel"]) Seleccionadas.Add(Convert.ToString(r["PO"]));

            if (Seleccionadas.Count == 0)
            {
                MessageBox.Show(this, "Marque pelo menos uma PO.", Text, MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }
            DialogResult = DialogResult.OK;
            Close();
        }
    }
}
'@
Set-Content -Path (Join-Path $Pasta "FrmSeleccaoPO.cs") -Value $f2 -Encoding UTF8
$f3 = @'
# ============================================================
#  Compilação da extensão ADF / PO – Cegid Evolution ERP Primavera V10
#  Grupo Naval Angola – Projectos Digitais. CONFIDENCIAL.
#
#  Usa o compilador C# do .NET Framework do Windows (csc.exe).
#  Executar no servidor do Primavera, com o ERP fechado:
#    powershell -ExecutionPolicy Bypass -File C:\Naval\Extensoes\Compilar.ps1
# ============================================================

$Apl   = "C:\Program Files\PRIMAVERA\SG100\Apl"
$Pasta = "C:\Naval\Extensoes"
$Src   = Join-Path $Pasta "*.cs"
$Out   = Join-Path $Pasta "Naval.Extensibility.ContasCorrentes.dll"
$Csc   = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe"

if (-not (Test-Path (Join-Path $Pasta "UiEditorPendentes.cs"))) { Write-Host "Falta o ficheiro UiEditorPendentes.cs em $Pasta" -ForegroundColor Red; exit 1 }
if (-not (Test-Path (Join-Path $Pasta "FrmSeleccaoPO.cs")))     { Write-Host "Falta o ficheiro FrmSeleccaoPO.cs em $Pasta" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $Csc)) { Write-Host "Compilador não encontrado: $Csc" -ForegroundColor Red; exit 1 }

$Padrao = '^(Primavera\.Extensibility\..+|I?StdPlatB[ES]100|StdBE100|ErpBS100|I?CctB[ES]100|BasBE100|IBasBS100)\.dll$'
$Dlls = Get-ChildItem $Apl -Filter *.dll | Where-Object { $_.Name -match $Padrao }
$Refs = @($Dlls | ForEach-Object { '/r:"' + $_.FullName + '"' }) + @("/r:System.Windows.Forms.dll", "/r:System.Drawing.dll", "/r:System.Data.dll", "/r:Microsoft.CSharp.dll", "/r:System.Core.dll")
Write-Host ("Referências encontradas: " + $Dlls.Count) -ForegroundColor Cyan

# Tentativa 1: método de aviso actual (MostraMensagem)
$r1 = & $Csc /nologo /target:library /optimize+ /platform:anycpu /define:NOVA_API /out:"$Out" $Refs "$Src" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Compilado com sucesso (método MostraMensagem): $Out" -ForegroundColor Green
    exit 0
}

# Tentativa 2: método MostraAviso (aviso de obsoleto ocultado)
Write-Host "MostraMensagem não disponível nesta versão do SDK - a usar MostraAviso." -ForegroundColor Yellow
& $Csc /nologo /target:library /optimize+ /platform:anycpu /out:"$Out" $Refs "$Src"
if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Compilado com sucesso (método MostraAviso): $Out" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Erros na compilação - ver a lista acima." -ForegroundColor Red
    Write-Host "Erros da tentativa com MostraMensagem (para referência):" -ForegroundColor DarkGray
    $r1 | ForEach-Object { Write-Host ("  " + $_) -ForegroundColor DarkGray }
}
'@
Set-Content -Path (Join-Path $Pasta "Compilar.ps1") -Value $f3 -Encoding UTF8
Write-Host "Ficheiros v1.2 criados em $Pasta" -ForegroundColor Cyan
powershell -ExecutionPolicy Bypass -File (Join-Path $Pasta "Compilar.ps1")
