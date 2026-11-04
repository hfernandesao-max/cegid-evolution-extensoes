// ============================================================
//  Naval.Extensibility.ContasCorrentes
//  Validação do n.º da PO no campo "Número do Documento" dos ADF.
//  Grupo Naval Angola – Projectos Digitais. CONFIDENCIAL.
//
//  1.0.0 (04/11/2026) Versão inicial: validação de uma ou mais PO.
//  1.1.0 (04/11/2026) Mensagens num só parágrafo (a janela ignora
//                     quebras de linha); método de aviso actual.
// ============================================================
using System;
using System.Collections.Generic;
using System.Reflection;
using System.Text.RegularExpressions;
using Primavera.Extensibility.BusinessEntities.ExtensibilityService.EventArgs;
using Primavera.Extensibility.PayablesReceivables.Editors;
using StdPlatBS100;

[assembly: AssemblyTitle("Naval – Validação PO nos ADF")]
[assembly: AssemblyDescription("Obriga a indicar PO válidas do fornecedor no Número do Documento dos ADF.")]
[assembly: AssemblyCompany("Grupo Naval Angola – Projectos Digitais")]
[assembly: AssemblyProduct("Naval.Extensibility.ContasCorrentes")]
[assembly: AssemblyCopyright("Grupo Naval Angola 2026 – Confidencial")]
[assembly: AssemblyVersion("1.1.0.0")]
[assembly: AssemblyFileVersion("1.1.0.0")]

namespace Naval.Extensibility.ContasCorrentes
{
    public class UiEditorPendentes : EditorPendentes
    {
        private const string TipoDocADF = "ADF";

        private static readonly Regex RxInicio = new Regex(
            @"^\s*(?:POL|POS|POM|POI|ECF|PO)\s+[A-Z0-9]+\s*/\s*\d+(?:\s*[;,]\s*(?:POL|POS|POM|POI|ECF|PO)\s+[A-Z0-9]+\s*/\s*\d+)*",
            RegexOptions.IgnoreCase | RegexOptions.Compiled);

        private static readonly Regex RxPO = new Regex(
            @"(?<tipo>POL|POS|POM|POI|ECF|PO)\s+(?<serie>[A-Z0-9]+)\s*/\s*(?<num>\d+)",
            RegexOptions.IgnoreCase | RegexOptions.Compiled);

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

            // 1) Estrutura
            Match inicio = RxInicio.Match(numDoc);
            if (!inicio.Success)
            {
                Bloquear(ref Cancel,
                    "O campo 'Número do Documento' tem de começar pelo n.º da PO deste fornecedor. " +
                    "Exemplo: PO 2026/756 - Natighe PP 2026A/89. " +
                    "Para várias PO, separe-as com ponto e vírgula: PO 2026/10; PO 2026/11 - Kituco PP2026B/11-12.");
                return;
            }

            // 2) Validação de cada PO
            var erros = new List<string>();
            var vistas = new HashSet<string>();

            foreach (Match m in RxPO.Matches(inicio.Value))
            {
                string tipo  = m.Groups["tipo"].Value.ToUpperInvariant();
                string serie = m.Groups["serie"].Value.ToUpperInvariant();
                string num   = m.Groups["num"].Value;
                string po    = tipo + " " + serie + "/" + num;

                if (!vistas.Add(po)) continue;

                string estado = ValidarPO(tipo, serie, num, fornecedor);
                if (estado != null) erros.Add(po + " " + estado);
            }

            if (erros.Count > 0)
            {
                Bloquear(ref Cancel,
                    "Não é possível gravar o adiantamento: " +
                    string.Join(" | ", erros.ToArray()) + ". " +
                    "Corrija o n.º da PO no campo 'Número do Documento'.");
            }
        }

        /// <summary>Devolve null se a PO for válida, ou o motivo da rejeição.</summary>
        private string ValidarPO(string tipo, string serie, string num, string fornecedor)
        {
            // Valores vêm da expressão regular (só letras e dígitos).
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
