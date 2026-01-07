defmodule Nasty.Statistics.Neural.Transformers.ConfigTest do
  use ExUnit.Case, async: false

  alias Nasty.Statistics.Neural.Transformers.Config

  setup do
    # Clear environment variables before each test
    original_env = %{
      cache_dir: System.get_env("NASTY_MODEL_CACHE_DIR"),
      hf_home: System.get_env("NASTY_HF_HOME"),
      model: System.get_env("NASTY_TRANSFORMER_MODEL"),
      gpu: System.get_env("NASTY_USE_GPU"),
      offline: System.get_env("NASTY_OFFLINE_MODE")
    }

    on_exit(fn ->
      # Restore original environment
      if original_env.cache_dir,
        do: System.put_env("NASTY_MODEL_CACHE_DIR", original_env.cache_dir)

      if original_env.hf_home, do: System.put_env("NASTY_HF_HOME", original_env.hf_home)
      if original_env.model, do: System.put_env("NASTY_TRANSFORMER_MODEL", original_env.model)
      if original_env.gpu, do: System.put_env("NASTY_USE_GPU", original_env.gpu)
      if original_env.offline, do: System.put_env("NASTY_OFFLINE_MODE", original_env.offline)

      # Delete if they weren't set
      unless original_env.cache_dir, do: System.delete_env("NASTY_MODEL_CACHE_DIR")
      unless original_env.hf_home, do: System.delete_env("NASTY_HF_HOME")
      unless original_env.model, do: System.delete_env("NASTY_TRANSFORMER_MODEL")
      unless original_env.gpu, do: System.delete_env("NASTY_USE_GPU")
      unless original_env.offline, do: System.delete_env("NASTY_OFFLINE_MODE")
    end)

    :ok
  end

  describe "get/0" do
    test "returns default configuration when no overrides" do
      # Clear env vars
      System.delete_env("NASTY_MODEL_CACHE_DIR")
      System.delete_env("NASTY_HF_HOME")
      System.delete_env("NASTY_TRANSFORMER_MODEL")
      System.delete_env("NASTY_USE_GPU")
      System.delete_env("NASTY_OFFLINE_MODE")

      config = Config.get()

      assert is_map(config)
      assert Map.has_key?(config, :cache_dir)
      assert Map.has_key?(config, :default_model)
      assert Map.has_key?(config, :backend)
      assert Map.has_key?(config, :device)
      assert Map.has_key?(config, :offline_mode)
    end

    test "returns configuration with all required keys" do
      config = Config.get()

      assert is_binary(config.cache_dir)
      assert is_atom(config.default_model)
      assert config.backend in [:exla, :nx_binary]
      assert config.device in [:cpu, :cuda]
      assert is_boolean(config.offline_mode)
    end

    test "default configuration values" do
      System.delete_env("NASTY_MODEL_CACHE_DIR")
      System.delete_env("NASTY_TRANSFORMER_MODEL")
      System.delete_env("NASTY_USE_GPU")
      System.delete_env("NASTY_OFFLINE_MODE")

      config = Config.get()

      # Default values
      assert config.default_model == :roberta_base
      assert config.backend == :exla
      assert config.device == :cpu
      assert config.offline_mode == false
    end
  end

  describe "get/1 with key" do
    test "returns specific configuration value" do
      assert is_binary(Config.get(:cache_dir))
      assert is_atom(Config.get(:default_model))
      assert is_atom(Config.get(:backend))
      assert is_atom(Config.get(:device))
      assert is_boolean(Config.get(:offline_mode))
    end

    test "returns nil for non-existent key" do
      assert Config.get(:nonexistent_key) == nil
    end
  end

  describe "environment variable precedence" do
    test "NASTY_MODEL_CACHE_DIR overrides default" do
      System.put_env("NASTY_MODEL_CACHE_DIR", "/custom/cache")

      config = Config.get()

      assert config.cache_dir == "/custom/cache"
    end

    test "NASTY_HF_HOME sets cache dir when NASTY_MODEL_CACHE_DIR not set" do
      System.delete_env("NASTY_MODEL_CACHE_DIR")
      System.put_env("NASTY_HF_HOME", "/home/user/.cache/huggingface")

      config = Config.get()

      assert String.contains?(config.cache_dir, "transformers")
    end

    test "NASTY_TRANSFORMER_MODEL overrides default model" do
      System.put_env("NASTY_TRANSFORMER_MODEL", "bert_base_cased")

      config = Config.get()

      assert config.default_model == :bert_base_cased
    end

    test "NASTY_USE_GPU=true sets device to cuda" do
      System.put_env("NASTY_USE_GPU", "true")

      config = Config.get()

      assert config.device == :cuda
    end

    test "NASTY_USE_GPU=false sets device to cpu" do
      System.put_env("NASTY_USE_GPU", "false")

      config = Config.get()

      assert config.device == :cpu
    end

    test "NASTY_OFFLINE_MODE=true enables offline mode" do
      System.put_env("NASTY_OFFLINE_MODE", "true")

      config = Config.get()

      assert config.offline_mode == true
    end

    test "NASTY_OFFLINE_MODE=false disables offline mode" do
      System.put_env("NASTY_OFFLINE_MODE", "false")

      config = Config.get()

      assert config.offline_mode == false
    end
  end

  describe "with_opts/1" do
    test "merges runtime options with config" do
      config = Config.with_opts(cache_dir: "/runtime/cache", device: :cuda)

      assert config.cache_dir == "/runtime/cache"
      assert config.device == :cuda
    end

    test "runtime options have highest precedence" do
      System.put_env("NASTY_MODEL_CACHE_DIR", "/env/cache")

      config = Config.with_opts(cache_dir: "/runtime/cache")

      assert config.cache_dir == "/runtime/cache"
    end

    test "preserves unmodified config values" do
      config = Config.with_opts(device: :cuda)

      # Other values should remain from base config
      assert is_atom(config.default_model)
      assert is_atom(config.backend)
      assert is_boolean(config.offline_mode)
    end
  end

  describe "cache_dir/0" do
    test "returns cache directory from NASTY_MODEL_CACHE_DIR" do
      System.put_env("NASTY_MODEL_CACHE_DIR", "/test/cache")

      assert Config.cache_dir() == "/test/cache"
    end

    test "returns cache directory from NASTY_HF_HOME when NASTY_MODEL_CACHE_DIR not set" do
      System.delete_env("NASTY_MODEL_CACHE_DIR")
      System.put_env("NASTY_HF_HOME", "/hf/home")

      cache_dir = Config.cache_dir()

      assert cache_dir == "/hf/home/transformers"
    end

    test "returns default when no env vars set" do
      System.delete_env("NASTY_MODEL_CACHE_DIR")
      System.delete_env("NASTY_HF_HOME")

      cache_dir = Config.cache_dir()

      assert is_binary(cache_dir)
      assert String.contains?(cache_dir, "transformers")
    end
  end

  describe "default_model/0" do
    test "returns default model from config" do
      System.delete_env("NASTY_TRANSFORMER_MODEL")

      assert Config.default_model() == :roberta_base
    end

    test "returns model from NASTY_TRANSFORMER_MODEL env var" do
      System.put_env("NASTY_TRANSFORMER_MODEL", "bert_base_uncased")

      assert Config.default_model() == :bert_base_uncased
    end
  end

  describe "device/0" do
    test "returns cpu by default" do
      System.delete_env("NASTY_USE_GPU")

      assert Config.device() == :cpu
    end

    test "returns cuda when NASTY_USE_GPU=true" do
      System.put_env("NASTY_USE_GPU", "true")

      assert Config.device() == :cuda
    end

    test "returns cpu when NASTY_USE_GPU=false" do
      System.put_env("NASTY_USE_GPU", "false")

      assert Config.device() == :cpu
    end

    test "returns default for invalid NASTY_USE_GPU value" do
      System.put_env("NASTY_USE_GPU", "invalid")

      device = Config.device()

      assert device in [:cpu, :cuda]
    end
  end

  describe "backend/0" do
    test "returns backend from config" do
      backend = Config.backend()

      assert backend in [:exla, :nx_binary]
    end
  end

  describe "offline_mode?/0" do
    test "returns false by default" do
      System.delete_env("NASTY_OFFLINE_MODE")

      assert Config.offline_mode?() == false
    end

    test "returns true when NASTY_OFFLINE_MODE=true" do
      System.put_env("NASTY_OFFLINE_MODE", "true")

      assert Config.offline_mode?() == true
    end

    test "returns false when NASTY_OFFLINE_MODE=false" do
      System.put_env("NASTY_OFFLINE_MODE", "false")

      assert Config.offline_mode?() == false
    end

    test "returns default for invalid NASTY_OFFLINE_MODE value" do
      System.put_env("NASTY_OFFLINE_MODE", "maybe")

      offline = Config.offline_mode?()

      assert is_boolean(offline)
    end
  end

  describe "to_keyword/0" do
    test "converts config to keyword list" do
      keyword_config = Config.to_keyword()

      assert is_list(keyword_config)
      assert Keyword.keyword?(keyword_config)
    end

    test "keyword list contains all config keys" do
      keyword_config = Config.to_keyword()

      assert Keyword.has_key?(keyword_config, :cache_dir)
      assert Keyword.has_key?(keyword_config, :default_model)
      assert Keyword.has_key?(keyword_config, :backend)
      assert Keyword.has_key?(keyword_config, :device)
      assert Keyword.has_key?(keyword_config, :offline_mode)
    end
  end

  describe "configuration precedence order" do
    test "runtime options override environment variables" do
      System.put_env("NASTY_USE_GPU", "true")

      config = Config.with_opts(device: :cpu)

      assert config.device == :cpu
    end

    test "environment variables override application config" do
      System.put_env("NASTY_TRANSFORMER_MODEL", "custom_model")

      config = Config.get()

      assert config.default_model == :custom_model
    end

    test "full precedence chain: runtime > env > app > default" do
      # Set environment variable
      System.put_env("NASTY_MODEL_CACHE_DIR", "/env/cache")

      # Get base config (env should override default)
      base_config = Config.get()
      assert base_config.cache_dir == "/env/cache"

      # Runtime options should override env
      runtime_config = Config.with_opts(cache_dir: "/runtime/cache")
      assert runtime_config.cache_dir == "/runtime/cache"
    end
  end
end
