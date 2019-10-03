defmodule Ctf.UI.Tween do
  import Scenic.Math.Vector2

  @north 0
  @pos_north 2 * :math.pi()
  @east 1.5 * :math.pi()

  @doc """
  Computes an interpolation between the option sets to be used for animation
  (currently only translate and rotate).
  """
  def tween(opts, dest, t, easing \\ &linear/3) do
    Enum.map(
      opts,
      fn
        {:translate, start} ->
          {:translate, translate(start, dest[:translate], t, easing)}

        {:rotate, start} ->
          {:rotate, rotate(start, dest[:rotate], t, easing)}

        ignored ->
          ignored
      end
    )
  end

  def translate(start, finish, t, easing) do
    finish
    |> sub(start)
    |> mul(easing.(0, 1, t))
    |> add(start)
  end

  def rotate(@north, @east, t, easing) do
    rotate(@pos_north, @east, t, easing)
  end

  def rotate(@east, @north, t, easing) do
    rotate(@east, @pos_north, t, easing)
  end

  def rotate(start, finish, t, easing) do
    easing.(start, finish, t)
  end

  # Easing functions based on http://www.robertpenner.com/easing/ but with the
  # duration normalized to 1.
  def linear(start, finish, t) do
    (finish - start) * t + start
  end

  def in_out_sine(start, finish, t) do
    -(finish - start) / 2 * (:math.cos(:math.pi() * t) - 1) + start
  end

  # @s 1.70158
  # def in_out_back(start, finish, t) do
  #   s = @s * 1.525
  #   t = t * 2
  #   c = finish - start

  #   if t < 1 do
  #     c / 2 * (t * t * ((s + 1) * t - s)) + start
  #   else
  #     t = t - 2
  #     c / 2 * (t * t * ((s + 1) * t + s) + 2) + start
  #   end
  # end
end
