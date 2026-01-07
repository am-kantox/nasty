defmodule Nasty.Statistics.Neural.TrainerTest do
  use ExUnit.Case, async: true

  alias Nasty.Statistics.Neural.Trainer

  describe "create_training_loop/2" do
    test "creates training loop with default config" do
      model = Axon.input("input", shape: {nil, 10})

      config = %{
        optimizer: :adam,
        learning_rate: 0.001,
        loss: :categorical_cross_entropy,
        metrics: [:accuracy]
      }

      loop = Trainer.create_training_loop(model, config)

      assert %Axon.Loop{} = loop
    end

    test "accepts custom optimizer" do
      model = Axon.input("input", shape: {nil, 10})

      config = %{
        optimizer: :sgd,
        learning_rate: 0.01,
        loss: :categorical_cross_entropy
      }

      loop = Trainer.create_training_loop(model, config)

      assert %Axon.Loop{} = loop
    end

    test "accepts custom loss function" do
      model = Axon.input("input", shape: {nil, 10})

      config = %{
        optimizer: :adam,
        learning_rate: 0.001,
        loss: :mean_squared_error
      }

      loop = Trainer.create_training_loop(model, config)

      assert %Axon.Loop{} = loop
    end

    test "handles multiple metrics" do
      model = Axon.input("input", shape: {nil, 10})

      config = %{
        optimizer: :adam,
        learning_rate: 0.001,
        loss: :categorical_cross_entropy,
        metrics: [:accuracy, :precision]
      }

      loop = Trainer.create_training_loop(model, config)

      assert %Axon.Loop{} = loop
    end
  end

  describe "get_optimizer/2" do
    test "returns Adam optimizer" do
      optimizer = Trainer.get_optimizer(:adam, learning_rate: 0.001)

      assert is_tuple(optimizer)
    end

    test "returns SGD optimizer" do
      optimizer = Trainer.get_optimizer(:sgd, learning_rate: 0.01)

      assert is_tuple(optimizer)
    end

    test "returns AdamW optimizer" do
      optimizer = Trainer.get_optimizer(:adamw, learning_rate: 0.001)

      assert is_tuple(optimizer)
    end

    test "uses default learning rate when not specified" do
      optimizer = Trainer.get_optimizer(:adam)

      assert is_tuple(optimizer)
    end
  end

  describe "add_early_stopping/2" do
    test "adds early stopping to training loop" do
      model = Axon.input("input", shape: {nil, 10})
      loop = Axon.Loop.trainer(model, :categorical_cross_entropy, :adam)

      loop_with_stopping = Trainer.add_early_stopping(loop, patience: 3)

      assert %Axon.Loop{} = loop_with_stopping
    end

    test "uses default patience when not specified" do
      model = Axon.input("input", shape: {nil, 10})
      loop = Axon.Loop.trainer(model, :categorical_cross_entropy, :adam)

      loop_with_stopping = Trainer.add_early_stopping(loop)

      assert %Axon.Loop{} = loop_with_stopping
    end
  end

  describe "add_checkpointing/2" do
    setup do
      tmp_dir = System.tmp_dir!() |> Path.join("test_checkpoints_#{:rand.uniform(10000)}")
      File.mkdir_p!(tmp_dir)

      on_exit(fn -> File.rm_rf!(tmp_dir) end)

      {:ok, checkpoint_dir: tmp_dir}
    end

    test "adds checkpointing to training loop", %{checkpoint_dir: dir} do
      model = Axon.input("input", shape: {nil, 10})
      loop = Axon.Loop.trainer(model, :categorical_cross_entropy, :adam)

      loop_with_checkpoints = Trainer.add_checkpointing(loop, checkpoint_dir: dir)

      assert %Axon.Loop{} = loop_with_checkpoints
    end

    test "uses specified event for checkpointing", %{checkpoint_dir: dir} do
      model = Axon.input("input", shape: {nil, 10})
      loop = Axon.Loop.trainer(model, :categorical_cross_entropy, :adam)

      loop_with_checkpoints =
        Trainer.add_checkpointing(loop,
          checkpoint_dir: dir,
          event: :epoch_completed
        )

      assert %Axon.Loop{} = loop_with_checkpoints
    end
  end

  describe "training_config/1" do
    test "creates default training configuration" do
      config = Trainer.training_config()

      assert config.optimizer == :adam
      assert config.learning_rate == 0.001
      assert config.loss == :categorical_cross_entropy
      assert is_list(config.metrics)
    end

    test "merges custom configuration with defaults" do
      config =
        Trainer.training_config(
          optimizer: :sgd,
          learning_rate: 0.01,
          custom_key: "value"
        )

      assert config.optimizer == :sgd
      assert config.learning_rate == 0.01
      assert config.custom_key == "value"
      assert config.loss == :categorical_cross_entropy
    end

    test "allows overriding all defaults" do
      config =
        Trainer.training_config(
          optimizer: :adamw,
          learning_rate: 0.0001,
          loss: :mean_squared_error,
          metrics: [:mae]
        )

      assert config.optimizer == :adamw
      assert config.learning_rate == 0.0001
      assert config.loss == :mean_squared_error
      assert config.metrics == [:mae]
    end
  end
end
