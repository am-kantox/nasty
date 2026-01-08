defmodule Nasty.Statistics.SequenceLabeling.Optimizer do
  @moduledoc """
  Gradient-based optimization for CRF training.

  Implements gradient descent with momentum and L2 regularization
  for training linear-chain CRFs.

  ## Optimization Methods

  - **SGD with Momentum**: Stochastic gradient descent with momentum term
  - **AdaGrad**: Adaptive learning rates per parameter
  - **L-BFGS (simplified)**: Limited-memory quasi-Newton method

  ## Regularization

  L2 regularization (ridge) to prevent overfitting:
  ```
  loss = -log_likelihood + λ * ||weights||²
  ```
  """

  @type weights :: map()
  @type gradient :: map()
  @type optimizer_state :: %{
          method: atom(),
          learning_rate: float(),
          momentum: float(),
          regularization: float(),
          velocity: map(),
          iteration: non_neg_integer()
        }

  @doc """
  Creates a new optimizer with specified configuration.

  ## Options

  - `:method` - Optimization method (`:sgd`, `:momentum`, `:adagrad`) (default: `:momentum`)
  - `:learning_rate` - Initial learning rate (default: 0.1)
  - `:momentum` - Momentum coefficient (default: 0.9)
  - `:regularization` - L2 regularization strength (default: 1.0)
  """
  @spec new(keyword()) :: optimizer_state()
  def new(opts \\ []) do
    %{
      method: Keyword.get(opts, :method, :momentum),
      learning_rate: Keyword.get(opts, :learning_rate, 0.1),
      momentum: Keyword.get(opts, :momentum, 0.9),
      regularization: Keyword.get(opts, :regularization, 1.0),
      velocity: %{},
      iteration: 0
    }
  end

  @doc """
  Performs one optimization step.

  Updates weights based on computed gradient.

  ## Parameters

  - `weights` - Current model weights
  - `gradient` - Gradient of loss function
  - `state` - Optimizer state

  ## Returns

  `{updated_weights, updated_state}`
  """
  @spec step(weights(), gradient(), optimizer_state()) :: {weights(), optimizer_state()}
  def step(weights, gradient, state) do
    case state.method do
      :sgd ->
        step_sgd(weights, gradient, state)

      :momentum ->
        step_momentum(weights, gradient, state)

      :adagrad ->
        step_adagrad(weights, gradient, state)

      _ ->
        step_momentum(weights, gradient, state)
    end
  end

  # Plain SGD
  defp step_sgd(weights, gradient, state) do
    lr = state.learning_rate
    reg = state.regularization

    updated_weights =
      Map.new(weights, fn {key, weight} ->
        grad = get_nested_value(gradient, key, 0.0)
        # w := w - lr * (grad + reg * w)
        new_weight = update_nested_weight(weight, grad, lr, reg)
        {key, new_weight}
      end)

    updated_state = %{state | iteration: state.iteration + 1}

    {updated_weights, updated_state}
  end

  # SGD with momentum
  defp step_momentum(weights, gradient, state) do
    lr = state.learning_rate
    momentum = state.momentum
    reg = state.regularization

    # Update velocity and weights
    {updated_weights, updated_velocity} =
      Enum.reduce(weights, {%{}, state.velocity}, fn {key, weight}, {w_acc, v_acc} ->
        grad = get_nested_value(gradient, key, 0.0)
        prev_velocity = get_nested_value(v_acc, key, 0.0)

        # v := momentum * v + lr * (grad + reg * w)
        new_velocity = update_velocity(prev_velocity, grad, weight, momentum, lr, reg)

        # w := w - v
        new_weight = subtract_nested(weight, new_velocity)

        {Map.put(w_acc, key, new_weight), Map.put(v_acc, key, new_velocity)}
      end)

    updated_state = %{
      state
      | velocity: updated_velocity,
        iteration: state.iteration + 1
    }

    {updated_weights, updated_state}
  end

  # AdaGrad with adaptive learning rates
  defp step_adagrad(weights, gradient, state) do
    lr = state.learning_rate
    reg = state.regularization
    epsilon = 1.0e-8

    # Update accumulated squared gradients
    {updated_weights, updated_velocity} =
      Enum.reduce(weights, {%{}, state.velocity}, fn {key, weight}, {w_acc, v_acc} ->
        grad = get_nested_value(gradient, key, 0.0)
        prev_sum_sq_grad = get_nested_value(v_acc, key, 0.0)

        # Accumulate squared gradient
        new_sum_sq_grad = add_nested(prev_sum_sq_grad, square_nested(grad))

        # Adaptive learning rate
        adapted_lr = divide_nested(lr, add_nested(sqrt_nested(new_sum_sq_grad), epsilon))

        # w := w - adapted_lr * (grad + reg * w)
        new_weight =
          subtract_nested(
            weight,
            multiply_nested(adapted_lr, add_nested(grad, multiply_nested(reg, weight)))
          )

        {Map.put(w_acc, key, new_weight), Map.put(v_acc, key, new_sum_sq_grad)}
      end)

    updated_state = %{
      state
      | velocity: updated_velocity,
        iteration: state.iteration + 1
    }

    {updated_weights, updated_state}
  end

  @doc """
  Computes gradient norm (L2 norm of gradient vector).

  Used for convergence checking.
  """
  @spec gradient_norm(gradient()) :: float()
  def gradient_norm(gradient) do
    gradient
    |> flatten_weights()
    |> Map.values()
    |> Enum.reduce(0.0, fn val, acc -> acc + val * val end)
    |> :math.sqrt()
  end

  @doc """
  Checks if optimization has converged.

  ## Convergence Criteria

  - Gradient norm < threshold
  - Relative improvement < threshold
  - Maximum iterations reached
  """
  @spec converged?(gradient(), float(), float(), keyword()) :: boolean()
  def converged?(gradient, prev_loss, curr_loss, opts \\ []) do
    grad_threshold = Keyword.get(opts, :grad_threshold, 0.01)
    loss_threshold = Keyword.get(opts, :loss_threshold, 1.0e-4)
    max_iterations = Keyword.get(opts, :max_iterations, 100)
    iteration = Keyword.get(opts, :iteration, 0)

    grad_norm = gradient_norm(gradient)

    # Handle infinity in loss values
    loss_improvement =
      cond do
        prev_loss == :infinity or curr_loss == :infinity -> 0.0
        prev_loss == :neg_infinity or curr_loss == :neg_infinity -> 0.0
        true -> abs(safe_subtract(prev_loss, curr_loss))
      end

    relative_improvement =
      if prev_loss != 0 and prev_loss != :infinity and prev_loss != :neg_infinity,
        do: loss_improvement / abs(prev_loss),
        else: loss_improvement

    cond do
      iteration >= max_iterations -> true
      grad_norm < grad_threshold -> true
      relative_improvement < loss_threshold -> true
      true -> false
    end
  end

  @doc """
  Applies L2 regularization to weights.

  Adds penalty term: λ/2 * ||w||²
  """
  @spec regularize_weights(weights(), float()) :: float()
  def regularize_weights(weights, lambda) do
    weights
    |> flatten_weights()
    |> Map.values()
    |> Enum.reduce(0.0, fn w, acc -> acc + w * w end)
    |> Kernel.*(lambda / 2.0)
  end

  @doc """
  Applies L2 regularization gradient.

  Gradient of regularization term: λ * w
  """
  @spec regularization_gradient(weights(), float()) :: gradient()
  def regularization_gradient(weights, lambda) do
    Map.new(weights, fn {key, weight} ->
      {key, lambda * weight}
    end)
  end

  @doc """
  Clips gradient values to prevent exploding gradients.

  ## Options

  - `:max_norm` - Maximum gradient norm (default: 5.0)
  """
  @spec clip_gradient(gradient(), keyword()) :: gradient()
  def clip_gradient(gradient, opts \\ []) do
    max_norm = Keyword.get(opts, :max_norm, 5.0)
    norm = gradient_norm(gradient)

    if norm > max_norm do
      scale = max_norm / norm

      Map.new(gradient, fn {key, val} ->
        {key, val * scale}
      end)
    else
      gradient
    end
  end

  @doc """
  Computes learning rate decay.

  ## Schedules

  - `:constant` - No decay
  - `:step` - Decay by factor every N steps
  - `:exponential` - Exponential decay
  - `:inverse` - 1 / (1 + decay * iteration)
  """
  @spec learning_rate_schedule(float(), non_neg_integer(), keyword()) :: float()
  def learning_rate_schedule(initial_lr, iteration, opts \\ []) do
    schedule = Keyword.get(opts, :schedule, :constant)

    case schedule do
      :constant ->
        initial_lr

      :step ->
        decay_factor = Keyword.get(opts, :decay_factor, 0.9)
        decay_steps = Keyword.get(opts, :decay_steps, 10)
        num_decays = div(iteration, decay_steps)
        initial_lr * :math.pow(decay_factor, num_decays)

      :exponential ->
        decay_rate = Keyword.get(opts, :decay_rate, 0.95)
        initial_lr * :math.pow(decay_rate, iteration)

      :inverse ->
        decay = Keyword.get(opts, :decay, 0.01)
        initial_lr / (1.0 + decay * iteration)

      _ ->
        initial_lr
    end
  end

  @doc """
  Initializes weights with small random values.

  Helps break symmetry and improve convergence.
  """
  @spec initialize_weights([term()], keyword()) :: weights()
  def initialize_weights(keys, opts \\ []) do
    scale = Keyword.get(opts, :scale, 0.01)

    Map.new(keys, fn key ->
      # Small random weight between -scale and +scale
      random_weight = :rand.uniform() * 2 * scale - scale
      {key, random_weight}
    end)
  end

  @doc """
  Adds weight values element-wise.

  Used for accumulating gradients.
  """
  @spec add_weights(weights(), weights()) :: weights()
  def add_weights(weights1, weights2) do
    all_keys = MapSet.union(MapSet.new(Map.keys(weights1)), MapSet.new(Map.keys(weights2)))

    Map.new(all_keys, fn key ->
      val1 = Map.get(weights1, key, %{})
      val2 = Map.get(weights2, key, %{})

      result =
        case {val1, val2} do
          {v1, v2} when is_map(v1) and is_map(v2) ->
            # Nested structure: add label maps
            label_keys = MapSet.union(MapSet.new(Map.keys(v1)), MapSet.new(Map.keys(v2)))

            Map.new(label_keys, fn label ->
              {label, Map.get(v1, label, 0.0) + Map.get(v2, label, 0.0)}
            end)

          {v1, v2} when is_number(v1) and is_number(v2) ->
            v1 + v2

          {v1, v2} when is_map(v1) and is_number(v2) ->
            if v2 == 0.0, do: v1, else: Map.new(v1, fn {k, v} -> {k, v + v2} end)

          {v1, v2} when is_number(v1) and is_map(v2) ->
            if v1 == 0.0, do: v2, else: Map.new(v2, fn {k, v} -> {k, v1 + v} end)

          _ ->
            0.0
        end

      {key, result}
    end)
  end

  @doc """
  Scales all weight values by a constant.
  """
  @spec scale_weights(weights(), float()) :: weights()
  def scale_weights(weights, scale) do
    Map.new(weights, fn {key, val} ->
      {key, scale_value(val, scale)}
    end)
  end

  # Get value from potentially nested structure
  defp get_nested_value(map, key, default) do
    case Map.get(map, key, default) do
      val when is_map(val) -> val
      val -> val
    end
  end

  # Update nested weight structure: w := w - lr * (grad + reg * w)
  defp update_nested_weight(weight, grad, lr, reg) when is_map(weight) and is_map(grad) do
    Map.new(weight, fn {label, w} ->
      g = Map.get(grad, label, 0.0)
      {label, w - lr * (g + reg * w)}
    end)
  end

  defp update_nested_weight(weight, grad, lr, reg) when is_number(weight) and is_number(grad) do
    weight - lr * (grad + reg * weight)
  end

  defp update_nested_weight(weight, _grad, _lr, _reg), do: weight

  # Update velocity: v := momentum * v + lr * (grad + reg * w)
  defp update_velocity(prev_v, grad, weight, momentum, lr, reg) when is_map(weight) do
    Map.new(weight, fn {label, w} ->
      g = get_in(grad, [label]) || 0.0
      prev = get_in(prev_v, [label]) || 0.0
      {label, momentum * prev + lr * (g + reg * w)}
    end)
  end

  defp update_velocity(prev_v, grad, weight, momentum, lr, reg)
       when is_number(weight) and is_number(grad) do
    prev = if is_number(prev_v), do: prev_v, else: 0.0
    momentum * prev + lr * (grad + reg * weight)
  end

  defp update_velocity(_prev_v, grad, _weight, _momentum, _lr, _reg), do: grad

  # Arithmetic operations on nested structures
  defp add_nested(a, b) when is_map(a) and is_map(b) do
    all_keys = MapSet.union(MapSet.new(Map.keys(a)), MapSet.new(Map.keys(b)))
    Map.new(all_keys, fn k -> {k, Map.get(a, k, 0.0) + Map.get(b, k, 0.0)} end)
  end

  defp add_nested(a, b) when is_number(a) and is_number(b), do: a + b

  defp add_nested(a, b) when is_map(a) and is_number(b),
    do: Map.new(a, fn {k, v} -> {k, v + b} end)

  defp add_nested(a, b) when is_number(a) and is_map(b),
    do: Map.new(b, fn {k, v} -> {k, a + v} end)

  defp subtract_nested(a, b) when is_map(a) and is_map(b) do
    all_keys = MapSet.union(MapSet.new(Map.keys(a)), MapSet.new(Map.keys(b)))

    Map.new(all_keys, fn k ->
      {k, safe_subtract(Map.get(a, k, 0.0), Map.get(b, k, 0.0))}
    end)
  end

  defp subtract_nested(a, b) when is_number(a) and is_number(b), do: safe_subtract(a, b)
  defp subtract_nested(a, _b) when is_map(a), do: a

  defp safe_subtract(a, b) do
    cond do
      a == :neg_infinity or b == :neg_infinity -> 0.0
      a == :infinity or b == :infinity -> 0.0
      not is_number(a) or not is_number(b) -> 0.0
      true -> a - b
    end
  end

  defp multiply_nested(a, b) when is_map(a) and is_map(b) do
    Map.new(a, fn {k, v} -> {k, v * Map.get(b, k, 1.0)} end)
  end

  defp multiply_nested(a, b) when is_number(a) and is_map(b),
    do: Map.new(b, fn {k, v} -> {k, a * v} end)

  defp multiply_nested(a, b) when is_map(a) and is_number(b),
    do: Map.new(a, fn {k, v} -> {k, v * b} end)

  defp multiply_nested(a, b) when is_number(a) and is_number(b), do: a * b

  defp divide_nested(a, b) when is_number(a) and is_map(b) do
    Map.new(b, fn {k, v} -> {k, a / v} end)
  end

  defp divide_nested(a, b) when is_number(a) and is_number(b), do: a / b

  defp square_nested(a) when is_map(a), do: Map.new(a, fn {k, v} -> {k, v * v} end)
  defp square_nested(a) when is_number(a), do: a * a

  defp sqrt_nested(a) when is_map(a), do: Map.new(a, fn {k, v} -> {k, :math.sqrt(v)} end)
  defp sqrt_nested(a) when is_number(a), do: :math.sqrt(a)

  # Flatten nested weight structure (for feature_weights with label maps)
  defp flatten_weights(weights) do
    Enum.reduce(weights, %{}, fn {key, val}, acc ->
      case val do
        v when is_map(v) ->
          # Nested structure: flatten {feature, label} => weight
          Enum.reduce(v, acc, fn {label, weight}, acc2 ->
            Map.put(acc2, {key, label}, weight)
          end)

        v when is_number(v) ->
          # Already flat
          Map.put(acc, key, v)

        _ ->
          acc
      end
    end)
  end

  # Scale value, handling nested maps
  defp scale_value(val, scale) when is_map(val) do
    Map.new(val, fn {k, v} -> {k, v * scale} end)
  end

  defp scale_value(val, scale) when is_number(val) do
    val * scale
  end
end
