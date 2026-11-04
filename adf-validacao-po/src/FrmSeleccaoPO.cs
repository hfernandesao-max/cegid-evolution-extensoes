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
