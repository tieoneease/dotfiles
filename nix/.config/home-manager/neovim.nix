{ pkgs, ... }: {
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withNodeJs = true;
    withPython3 = true;

    extraPackages = with pkgs; [
      # Language servers
      lua-language-server
      nil
      nodePackages.bash-language-server
      nodePackages.typescript-language-server
      nodePackages.svelte-language-server
      nodePackages.vscode-langservers-extracted # HTML, CSS, JSON, ESLint
      gopls
      python311Packages.python-lsp-server # Python LSP
      
      # Additional tools
      ripgrep
      fd
    ];

    plugins = with pkgs.vimPlugins; [
      # Essential plugins
      {
        plugin = plenary-nvim;
        type = "lua";
      }
      {
        plugin = nui-nvim;
        type = "lua";
      }
      {
        plugin = nvim-web-devicons;
        type = "lua";
        config = ''
          require("nvim-web-devicons").setup()
        '';
      }
      
      # LSP
      {
        plugin = nvim-lspconfig;
        type = "lua";
      }
      {
        plugin = mason-nvim;
        type = "lua";
        config = ''
          require("mason").setup({
            ui = {
              border = "rounded"
            }
          })
        '';
      }
      {
        plugin = mason-lspconfig-nvim;
        type = "lua";
        config = ''
          require("mason-lspconfig").setup({
            automatic_installation = false
          })

          -- LSP configurations
          local lspconfig = require("lspconfig")
          
          -- Lua LSP
          lspconfig.lua_ls.setup({
            settings = {
              Lua = {
                runtime = {
                  version = "LuaJIT"
                },
                diagnostics = {
                  globals = {"vim"}
                },
                workspace = {
                  library = vim.api.nvim_get_runtime_file("", true)
                },
                telemetry = {
                  enable = false
                }
              }
            }
          })

          -- Nix LSP
          lspconfig.nil_ls.setup({})

          -- Bash LSP
          lspconfig.bashls.setup({})

          -- TypeScript LSP
          lspconfig.tsserver.setup({})

          -- Svelte LSP
          lspconfig.svelte.setup({})

          -- HTML LSP
          lspconfig.html.setup({})

          -- Go LSP
          lspconfig.gopls.setup({})

          -- Python LSP
          lspconfig.pylsp.setup({})

          -- Global mappings
          vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float)
          vim.keymap.set("n", "[d", vim.diagnostic.goto_prev)
          vim.keymap.set("n", "]d", vim.diagnostic.goto_next)
          vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist)

          -- Use LspAttach autocommand to only map the following keys
          -- after the language server attaches to the current buffer
          vim.api.nvim_create_autocmd("LspAttach", {
            group = vim.api.nvim_create_augroup("UserLspConfig", {}),
            callback = function(ev)
              local opts = { buffer = ev.buf }
              vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
              vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
              vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
              vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
              vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts)
              vim.keymap.set("n", "<leader>wa", vim.lsp.buf.add_workspace_folder, opts)
              vim.keymap.set("n", "<leader>wr", vim.lsp.buf.remove_workspace_folder, opts)
              vim.keymap.set("n", "<leader>wl", function()
                print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
              end, opts)
              vim.keymap.set("n", "<leader>D", vim.lsp.buf.type_definition, opts)
              vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
              vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts)
              vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
              vim.keymap.set("n", "<leader>f", function()
                vim.lsp.buf.format { async = true }
              end, opts)
            end,
          })
        '';
      }
      {
        plugin = null-ls-nvim;
        type = "lua";
      }
      
      # Completion
      {
        plugin = nvim-cmp;
        type = "lua";
      }
      {
        plugin = cmp-nvim-lsp;
        type = "lua";
      }
      {
        plugin = cmp-buffer;
        type = "lua";
      }
      {
        plugin = cmp-path;
        type = "lua";
      }
      {
        plugin = cmp-cmdline;
        type = "lua";
      }
      {
        plugin = luasnip;
        type = "lua";
      }
      {
        plugin = cmp_luasnip;
        type = "lua";
      }
      {
        plugin = friendly-snippets;
        type = "lua";
      }
      
      # Treesitter
      {
        plugin = (nvim-treesitter.withPlugins (p: [
          p.tree-sitter-nix
          p.tree-sitter-lua
          p.tree-sitter-vim
          p.tree-sitter-bash
          p.tree-sitter-markdown
          p.tree-sitter-markdown-inline
          p.tree-sitter-typescript
          p.tree-sitter-javascript
          p.tree-sitter-html
          p.tree-sitter-css
          p.tree-sitter-go
          p.tree-sitter-python
          p.tree-sitter-svelte
        ]));
        type = "lua";
        config = ''
          require("nvim-treesitter.configs").setup({
            highlight = { enable = true },
            indent = { enable = true }
          })
        '';
      }
      
      # File navigation
      {
        plugin = telescope-nvim;
        type = "lua";
        config = ''
          local telescope = require("telescope")
          telescope.setup()
          vim.keymap.set("n", "<leader>ff", require("telescope.builtin").find_files)
          vim.keymap.set("n", "<leader>fg", require("telescope.builtin").live_grep)
          vim.keymap.set("n", "<leader>fb", require("telescope.builtin").buffers)
          vim.keymap.set("n", "<leader>fh", require("telescope.builtin").help_tags)
        '';
      }
      {
        plugin = nvim-tree-lua;
        type = "lua";
        config = ''
          require("nvim-tree").setup()
          vim.keymap.set("n", "<leader>nt", ":NvimTreeToggle<CR>")
        '';
      }
      
      # UI enhancements
      {
        plugin = lualine-nvim;
        type = "lua";
        config = ''
          require("lualine").setup({
            options = {
              theme = "catppuccin",
              component_separators = "|",
              section_separators = " "
            }
          })
        '';
      }
      {
        plugin = noice-nvim;
        type = "lua";
        config = ''
          require("noice").setup({
            lsp = {
              override = {
                ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
                ["vim.lsp.util.stylize_markdown"] = true,
                ["cmp.entry.get_documentation"] = true
              }
            },
            presets = {
              bottom_search = true,
              command_palette = true,
              long_message_to_split = true,
              inc_rename = false,
              lsp_doc_border = false
            }
          })
        '';
      }
      {
        plugin = catppuccin-nvim;
        type = "lua";
        config = ''
          require("catppuccin").setup({
            flavour = "mocha",
            transparent_background = true
          })
          vim.cmd.colorscheme "catppuccin"
        '';
      }
      {
        plugin = zen-mode-nvim;
        type = "lua";
        config = ''
          require("zen-mode").setup()
          vim.keymap.set("n", "<leader>z", ":ZenMode<CR>")
        '';
      }
      {
        plugin = twilight-nvim;
        type = "lua";
        config = ''
          require("twilight").setup()
        '';
      }
      
      # Terminal
      {
        plugin = FTerm-nvim;
        type = "lua";
        config = ''
          require("FTerm").setup()
          vim.keymap.set("n", "<A-i>", ":lua require('FTerm').toggle()<CR>")
          vim.keymap.set("t", "<A-i>", "<C-\\><C-n><CMD>lua require('FTerm').toggle()<CR>")
        '';
      }
      
      # Git
      {
        plugin = lazygit-nvim;
        type = "lua";
        config = ''
          vim.keymap.set("n", "<leader>lg", ":LazyGit<CR>")
        '';
      }
      
      # Additional functionality
      {
        plugin = nvim-surround;
        type = "lua";
        config = ''
          require("nvim-surround").setup()
        '';
      }
      {
        plugin = comment-nvim;
        type = "lua";
        config = ''
          require("Comment").setup()
        '';
      }
      {
        plugin = undotree;
        type = "lua";
      }
      {
        plugin = todo-comments-nvim;
        type = "lua";
        config = ''
          require("todo-comments").setup()
        '';
      }
      {
        plugin = nvim-autopairs;
        type = "lua";
        config = ''
          require("nvim-autopairs").setup()
        '';
      }
      {
        plugin = vim-tmux-navigator;
        type = "lua";
      }
    ];

    extraLuaConfig = ''
      -- Basic settings
      vim.g.mapleader = ","
      vim.opt.clipboard = "unnamedplus"
      vim.opt.splitbelow = true
      vim.opt.splitright = true

      -- Additional vim options
      vim.opt.number = true
      vim.opt.relativenumber = true
      vim.opt.tabstop = 2
      vim.opt.shiftwidth = 2
      vim.opt.expandtab = true
      vim.opt.smartindent = true
      vim.opt.wrap = false
      vim.opt.swapfile = false
      vim.opt.backup = false
      vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
      vim.opt.undofile = true
      vim.opt.hlsearch = false
      vim.opt.incsearch = true
      vim.opt.termguicolors = true
      vim.opt.scrolloff = 8
      vim.opt.signcolumn = "yes"
      vim.opt.updatetime = 50
      vim.opt.colorcolumn = "80"

      -- Key mappings
      vim.keymap.set("n", ";", ":")
      vim.keymap.set("i", "jj", "<Esc>")
      vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
      vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")
      vim.keymap.set("x", "<leader>p", [["_dP]])
      vim.keymap.set("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])
      vim.keymap.set("n", "<leader>x", "<cmd>!chmod +x %<CR>", { silent = true })

      -- Window navigation
      vim.keymap.set("n", "<leader>w", "<C-w>", { noremap = true, silent = true })
      vim.keymap.set("n", "<C-h>", "<C-w>h", { noremap = true, silent = true })
      vim.keymap.set("n", "<C-j>", "<C-w>j", { noremap = true, silent = true })
      vim.keymap.set("n", "<C-k>", "<C-w>k", { noremap = true, silent = true })
      vim.keymap.set("n", "<C-l>", "<C-w>l", { noremap = true, silent = true })

      -- Tab management
      vim.keymap.set("n", "<leader>tn", ":tab split<CR>", { noremap = true, silent = true })
      vim.keymap.set("n", "<C-S-tab>", ":tabp<CR>", { noremap = true, silent = true })
      vim.keymap.set("n", "<C-tab>", ":tabn<CR>", { noremap = true, silent = true })
      vim.keymap.set("n", "<C-S-PageUp>", ":tabmove -1<CR>", { noremap = true, silent = true })
      vim.keymap.set("n", "<C-S-PageDown>", ":tabmove +1<CR>", { noremap = true, silent = true })

      -- Tmux integration
      vim.keymap.set("n", "<C-f>", "<cmd>silent !tmux display-popup tms switch<CR>")
      vim.keymap.set("n", "<C-n>", "<cmd>silent !tmux display-popup tms<CR>")

      -- Completion setup
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      require("luasnip.loaders.from_vscode").lazy_load()

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true })
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "path" }
        }, {
          { name = "buffer" }
        })
      })

      -- Set up buffer-local keymaps / options
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "help", "man" },
        callback = function(event)
          vim.bo[event.buf].buflisted = false
          vim.keymap.set("n", "q", ":q<CR>", { buffer = event.buf, silent = true })
        end
      })

      -- Create undo directory
      local undodir = vim.fn.expand("~/.vim/undodir")
      if vim.fn.isdirectory(undodir) == 0 then
        vim.fn.mkdir(undodir, "p")
      end
    '';
  };
}
