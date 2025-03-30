<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" class="logo" width="120"/>

# 

---

# also, can you create a short readme from our research on the LLM tool so I can save it to my dotfiles?

Certainly! Below is a concise README for Simon Willison's LLM tool, based on the research we've discussed. You can save this to your dotfiles repository for quick reference.

---

# **LLM Tool README**

Simon Willison's LLM tool is a command-line utility for interacting with large language models (LLMs). It supports plugins for various providers and features, enabling flexible usage and customization.

---

## **Installation**

Install the tool using `pip`:

```bash
pip install llm
```

---

## **Key Features**

- **Model Aliases**: Simplify model names with custom aliases.
- **Plugins**: Extend functionality with plugins like `llm-anthropic`, `llm-cmd`, and `llm-perplexity`.
- **Default Model**: Set a default model for all prompts.
- **Shell Command Generation**: Generate executable shell commands from natural language descriptions.

---

## **Common Commands**

### **Set Up API Keys**

```bash
llm keys set <provider>
```

Example for Anthropic:

```bash
llm keys set anthropic
```


### **List Available Models**

```bash
llm models --options
```


### **Set Default Model**

```bash
llm models default <model-id>
```

Example:

```bash
llm models default claude-3.5-sonnet
```


### **Create Model Aliases**

```bash
llm aliases set <alias> <model-id>
```

Example:

```bash
llm aliases set sonnet claude-3.5-sonnet
```


### **Generate Shell Commands**

Use natural language to generate shell commands:

```bash
llm cmd <description>
```

Example:

```bash
llm cmd list all files including hidden ones
```

---

## **Plugins**

### **Anthropic (Claude)**

Install the plugin:

```bash
llm install llm-anthropic
```

Set the API key:

```bash
llm keys set anthropic
```


### **Perplexity**

Install the plugin:

```bash
llm install llm-perplexity
```

Set the API key:

```bash
llm keys set perplexity
```


### **Command Generation**

Install the plugin:

```bash
llm install llm-cmd
```

Generate shell commands:

```bash
llm cmd <description>
```

---

## **Configuration File Locations**

### Aliases Configuration Path:

Find the alias file path:

```bash
llm aliases path
```

---

## **Safety Tips**

- Always review generated shell commands before executing them.
- Be cautious when using powerful LLMs to avoid unintended consequences.

---

This README provides a quick reference for setting up and using the LLM tool effectively. Save it in your dotfiles repository for easy access!

