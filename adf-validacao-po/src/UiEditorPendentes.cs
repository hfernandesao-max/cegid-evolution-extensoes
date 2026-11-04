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
