Code.require_file "../test_helper.exs", __DIR__

defmodule IEx.HelpersTest do
  use IEx.Case

  import IEx.Helpers

  test "clear helper" do
    Application.put_env(:elixir, :ansi_enabled, true)
    assert capture_iex("clear") == "\e[H\e[2J"

    Application.put_env(:elixir, :ansi_enabled, false)
    assert capture_iex("clear") =~ "Cannot clear the screen because ANSI escape codes are not enabled on this shell"
  after
    Application.delete_env(:elixir, :ansi_enabled)
  end

  test "h helper" do
    assert "* IEx.Helpers\n\nWelcome to Interactive Elixir" <> _
           = capture_iex("h")
  end

  test "h helper module" do
    assert "* IEx.Helpers\n\nWelcome to Interactive Elixir" <> _ =
           capture_io(fn -> h IEx.Helpers end)

    assert capture_io(fn -> h :whatever end) ==
           "Could not load module :whatever, got: nofile\n"

    assert capture_io(fn -> h :lists end) ==
           ":lists is an Erlang module and, as such, it does not have Elixir-style docs\n"
  end

  test "h helper function" do
    pwd_h = "* def pwd()\n\nPrints the current working directory.\n\n"
    c_h   = "* def c(files, path \\\\ \".\")\n\nCompiles the given files."

    assert capture_io(fn -> h IEx.Helpers.pwd/0 end) =~ pwd_h
    assert capture_io(fn -> h IEx.Helpers.c/2 end) =~ c_h

    assert capture_io(fn -> h IEx.Helpers.c/1 end) =~ c_h
    assert capture_io(fn -> h pwd end) =~ pwd_h
  end

  test "h helper __info__" do
    h_output_module = capture_io(fn -> h Module.__info__ end)
    assert capture_io(fn -> h Module.UnlikelyTo.Exist.__info__ end) == h_output_module
    assert capture_io(fn -> h Module.UnlikelyTo.Exist.__info__/1 end) == h_output_module
    assert capture_io(fn -> h __info__ end) == "No documentation for __info__ was found\n"
  end

  test "h helper for callbacks" do
    with_file ["a_behaviour.ex", "impl.ex"], [behaviour_module, impl_module], fn ->
      c("a_behaviour.ex")
      c("impl.ex")
      assert capture_io(fn -> h Impl.first/1 end) == "* @callback first(integer()) :: integer()\n\nDocs for ABehaviour.first\n"
      assert capture_io(fn -> h Impl.second/1 end) == "* def second(int)\n\nDocs for Impl.second\n"
      assert capture_io(fn -> h Impl.third/1 end) == "* def third(int)\n\n\n"

      assert capture_io(fn -> h Impl.first end) == "* @callback first(integer()) :: integer()\n\nDocs for ABehaviour.first\n"
      assert capture_io(fn -> h Impl.second end) == "* def second(int)\n\nDocs for Impl.second\n"
      assert capture_io(fn -> h Impl.third end) == "* def third(int)\n\n\n"
    end
  after
    cleanup_modules([ABehaviour, Impl])
  end

  test "h helper for delegates" do
    filename = "delegate.ex"
    with_file filename, delegator_module <> "\n" <> delegated_module, fn ->
      assert c(filename) |> Enum.sort == [Delegated, Delegator]

      assert capture_io(fn -> h Delegator.func1 end) == "* def func1()\n\nSee `Delegated.func1/0`.\n"
      assert capture_io(fn -> h Delegator.func2 end) == "* def func2()\n\nDelegator func2 doc\n"
    end
  after
    cleanup_modules([Delegated, Delegator])
  end

  test "b helper module" do
    assert capture_io(fn -> b Mix end) == "No callbacks for Mix were found\n"
    assert capture_io(fn -> b NoMix end) == "Could not load module NoMix, got: nofile\n"
    assert capture_io(fn -> b Mix.SCM end) =~ """
    @callback accepts_options(app :: atom(), opts()) :: opts() | nil
    @callback checked_out?(opts()) :: boolean()
    """
  end

  test "b helper function" do
    assert capture_io(fn -> b Mix.Task.stop end) == "No documentation for Mix.Task.stop was found\n"
    assert capture_io(fn -> b Mix.Task.run end) =~ "* @callback run([binary()]) :: any()\n\nA task needs to implement `run`"
    assert capture_io(fn -> b NoMix.run end) == "Could not load module NoMix, got: nofile\n"
    assert capture_io(fn -> b Exception.message/1 end) == "* @callback message(t()) :: String.t()\n\n\n"
  end

  test "t helper" do
    assert capture_io(fn -> t IEx end) == "No type information for IEx was found\n"

    # Test that it shows at least two types
    assert Enum.count(capture_io(fn -> t Enum end) |> String.split("\n"), fn line ->
      String.starts_with? line, "@type"
    end) >= 2

    assert "@type t() :: " <> _
           = capture_io(fn -> t Enum.t end)
    assert capture_io(fn -> t Enum.t end) == capture_io(fn -> t Enum.t/0 end)

    assert "@opaque t()\n" = capture_io(fn -> t MapSet.t end)
    assert capture_io(fn -> t MapSet.t end) == capture_io(fn -> t MapSet.t/0 end)

    filename = "typesample.ex"
    with_file filename, module_with_typespecs, fn ->
      c(filename)
      assert capture_io(fn -> t TypeSample.id_with_desc/0 end) == """
      An id with description.
      @type id_with_desc() :: {number(), String.t()}
      """
      assert capture_io(fn -> t TypeSample.id_with_desc end) == """
      An id with description.
      @type id_with_desc() :: {number(), String.t()}
      """
    end
  after
    cleanup_modules([TypeSample])
  end

  test "s helper" do
    assert capture_io(fn -> s ExUnit end) == "No specification for ExUnit was found\n"

    # Test that it shows at least two specs
    assert Enum.count(capture_io(fn -> s Enum end) |> String.split("\n"), fn line ->
      String.starts_with? line, "@spec"
    end) >= 2

    assert Enum.count(capture_io(fn -> s Enum.all? end) |> String.split("\n"), fn line ->
      String.starts_with? line, "@spec"
    end) >= 2

    assert capture_io(fn -> s Enum.all?/1 end) ==
           "@spec all?(t()) :: boolean()\n"
    assert capture_io(fn -> s struct end) ==
           "@spec struct(module() | map(), Enum.t()) :: map()\n"
  end

  test "v helper" do
    assert "** (RuntimeError) v(0) is out of bounds" <> _
           = capture_iex("v(0)")
    assert capture_iex("1\n2\nv(2)") == "1\n2\n2"
    assert capture_iex("1\n2\nv(2)") == capture_iex("1\n2\nv(-1)")
    assert capture_iex("1\n2\nv(2)") == capture_iex("1\n2\nv()")
  end

  test "flush helper" do
    assert capture_io(fn -> send self(), :hello; flush end) == ":hello\n"
  end

  test "pwd helper" do
    File.cd! iex_path, fn ->
      assert capture_io(fn -> pwd end) =~ ~r"lib[\\/]iex\n$"
    end
  end

  test "ls helper" do
    File.cd! iex_path, fn ->
      paths = capture_io(fn -> ls end)
              |> String.split
              |> Enum.map(&String.strip(&1))

      assert "ebin" in paths
      assert "mix.exs" in paths

      assert capture_io(fn -> ls "~" end) ==
             capture_io(fn -> ls System.user_home end)
    end
  end

  test "import_file helper" do
    with_file "dot-iex", "variable = :hello\nimport IO", fn ->
      assert "** (CompileError) iex:1: undefined function variable/0" <> _
             = capture_iex("variable")
      assert "** (CompileError) iex:1: undefined function puts/1" <> _
             = capture_iex("puts \"hi\"")

      assert capture_iex("import_file \"dot-iex\"\nvariable\nputs \"hi\"")
             == "nil\n:hello\nhi\n:ok"
    end
  end

  test "import_file nested" do
    dot   = "parent = true\nimport_file \"dot-iex-1\""
    dot_1 = "variable = :hello\nimport IO"

    with_file ["dot-iex", "dot-iex-1"], [dot, dot_1], fn ->
      assert "** (CompileError) iex:1: undefined function parent/0" <> _
             = capture_iex("parent")
      assert "** (CompileError) iex:1: undefined function puts/1" <> _
             = capture_iex("puts \"hi\"")

      assert capture_iex("import_file \"dot-iex\"\nvariable\nputs \"hi\"\nparent")
             == "nil\n:hello\nhi\n:ok\ntrue"
    end
  end

  test "import_file when the file is missing" do
    assert "nil" == capture_iex("import_file \"nonexistent\", optional: true")

    failing = capture_iex("import_file \"nonexistent\"")
    assert "** (File.Error) could not read file" <> _ = failing
    assert failing =~ "no such file or directory"
  end

  test "c helper" do
    assert_raise UndefinedFunctionError, ~r"undefined function: Sample\.run/0", fn ->
      Sample.run
    end

    filename = "sample.ex"
    with_file filename, test_module_code, fn ->
      assert c(filename) == [Sample]
      assert Sample.run == :run
    end
  after
    cleanup_modules([Sample])
  end

  test "c helper with full path" do
    filename = "sample.ex"
    with_file filename, test_module_code, fn ->
      assert c(Path.expand(filename)) == [Sample]
      assert Sample.run == :run
    end
  after
    cleanup_modules([Sample])
  end

  test "c helper multiple modules" do
    assert_raise UndefinedFunctionError, ~r"undefined function: Sample.run/0", fn ->
      Sample.run
    end

    filename = "sample.ex"
    with_file filename, test_module_code <> "\n" <> another_test_module, fn ->
      assert c(filename) |> Enum.sort == [Sample, Sample2]
      assert Sample.run == :run
      assert Sample2.hello == :world
    end
  after
    cleanup_modules([Sample, Sample2])
  end

  test "c helper list" do
    assert_raise UndefinedFunctionError, ~r"undefined function: Sample.run/0", fn ->
      Sample.run
    end

    filenames = ["sample1.ex", "sample2.ex"]
    with_file filenames, [test_module_code, another_test_module], fn ->
      assert c(filenames) |> Enum.sort == [Sample, Sample2]
      assert Sample.run == :run
      assert Sample2.hello == :world
    end
  after
    cleanup_modules([Sample, Sample2])
  end

  test "c helper erlang" do
    assert_raise UndefinedFunctionError, ~r"undefined function: :sample.hello/0", fn ->
      :sample.hello
    end

    filename = "sample.erl"
    with_file filename, erlang_module_code, fn ->
      assert c(filename) == [:sample]
      assert :sample.hello == :world
    end
  after
    cleanup_modules([:sample])
  end


  test "c helper skips unknown files" do
    assert_raise UndefinedFunctionError, ~r"undefined function: :sample.hello/0", fn ->
      :sample.hello
    end

   filenames = ["sample.erl", "not_found.ex", "sample2.ex"]
   with_file filenames, [erlang_module_code, "", another_test_module], fn ->
      assert c(filenames) |> Enum.sort == [Sample2, :sample]
      assert :sample.hello == :world
      assert Sample2.hello == :world
    end
  after
    cleanup_modules([:sample, Sample2])
  end


  test "l helper" do
    assert_raise UndefinedFunctionError, ~r"undefined function: Sample.run/0", fn ->
      Sample.run
    end

    assert l(:non_existent_module) == {:error, :nofile}

    filename = "sample.ex"
    with_file filename, test_module_code, fn ->
      assert c(filename) == [Sample]
      assert Sample.run == :run

      File.write! filename, "defmodule Sample do end"
      elixirc ["sample.ex"]

      assert l(Sample) == {:module, Sample}
      assert_raise UndefinedFunctionError, "undefined function: Sample.run/0", fn ->
        Sample.run
      end
    end
  after
    # Clean up the old version left over after l()
    cleanup_modules([Sample])
  end

  test "r helper unavailable" do
    assert_raise ArgumentError, "could not load nor find module: :non_existent_module", fn ->
      r :non_existent_module
    end
  end

  test "r helper elixir" do
    assert_raise UndefinedFunctionError, ~r"undefined function: Sample.run/0 \(module Sample is not available\)", fn ->
      Sample.run
    end

    filename = "sample.ex"
    with_file filename, test_module_code, fn ->
      assert capture_io(:stderr, fn ->
        assert c(filename) == [Sample]
        assert Sample.run == :run

        File.write! filename, "defmodule Sample do end"
        assert {:reloaded, Sample, [Sample]} = r(Sample)
        assert_raise UndefinedFunctionError, "undefined function: Sample.run/0", fn ->
          Sample.run
        end
      end) =~ ~r"^.*?sample\.ex:1: warning: redefining module Sample\n$"
    end
  after
    # Clean up old version produced by the r helper
    cleanup_modules([Sample])
  end

  test "r helper erlang" do
    assert_raise UndefinedFunctionError, ~r"undefined function: :sample.hello/0", fn ->
      :sample.hello
    end

    filename = "sample.erl"
    with_file filename, erlang_module_code, fn ->
      assert c(filename) == [:sample]
      assert :sample.hello == :world

      File.write!(filename, other_erlang_module_code)
      assert {:reloaded, :sample, [:sample]} = r(:sample)
      assert :sample.hello == :bye
    end
  after
    cleanup_modules([:sample])
  end

  test "pid helper" do
    assert "#PID<0.32767.3276>" == capture_iex("pid(0,32767,3276)")
    assert "#PID<0.5.6>" == capture_iex("pid(0,5,6)")
    assert "** (FunctionClauseError) no function clause matching in IEx.Helpers.pid/3" <> _ =
      capture_iex("pid(0,6,-6)")
  end

  test "m helper" do
    loaded = capture_iex("m")
    assert loaded =~ ":erlang\n  :preloaded"
    assert loaded =~ ~r/IEx\n.*\.beam/
  end

  test "m module helper" do
    assert capture_iex("m IEx") =~ ~r/Module\:\n  IEx/
    assert capture_iex("m Atom") =~ ~r/Compile Time\:\n  \d*\-\d*\-\d* \d*\:\d*\:\d*/
    assert capture_iex("m :erlang") =~ ~r/\Module\:\n  \:erlang/
  end

  defp test_module_code do
    """
    defmodule Sample do
      def run do
        :run
      end
    end
    """
  end

  defp another_test_module do
    """
    defmodule Sample2 do
      def hello do
        :world
      end
    end
    """
  end

  defp behaviour_module do
    """
    defmodule ABehaviour do
      use Behaviour
      @doc "Docs for ABehaviour.first"
      defcallback first(integer) :: integer
      defcallback second(integer) :: integer
    end
    """
  end

  defp impl_module do
    """
    defmodule Impl do
      @behaviour ABehaviour
      def first(0), do: 0
      @doc "Docs for Impl.second"
      def second(0), do: 0
      def third(0), do: 0
    end
    """
  end

  defp delegator_module do
    """
    defmodule Delegator do
      defdelegate func1, to: Delegated
      @doc "Delegator func2 doc"
      defdelegate func2, to: Delegated
    end
    """
  end

  defp delegated_module do
    """
    defmodule Delegated do
      def func1, do: 1
      def func2, do: 2
    end
    """
  end

  defp erlang_module_code do
    """
    -module(sample).
    -export([hello/0]).
    hello() -> world.
    """
  end

  defp other_erlang_module_code do
    """
    -module(sample).
    -export([hello/0]).
    hello() -> bye.
    """
  end

  def module_with_typespecs do
    """
    defmodule TypeSample do
      @typedoc "An id with description."
      @type id_with_desc :: {number, String.t}
    end
    """
  end

  defp cleanup_modules(mods) do
    Enum.each mods, fn mod ->
      File.rm("#{mod}.beam")
      :code.purge(mod)
      true = :code.delete(mod)
    end
  end

  defp with_file(names, codes, fun) when is_list(names) and is_list(codes) do
    Enum.each Enum.zip(names, codes), fn {name, code} ->
      File.write! name, code
    end

    try do
      fun.()
    after
      Enum.each names, &File.rm/1
    end
  end

  defp with_file(name, code, fun) do
    with_file(List.wrap(name), List.wrap(code), fun)
  end

  defp elixirc(args) do
    executable = Path.expand("../../../../bin/elixirc", __DIR__)
    System.cmd("#{executable}#{executable_extension}", args, [stderr_to_stdout: true])
  end

  defp iex_path do
    Path.expand "../..", __DIR__
  end

  if match? {:win32, _}, :os.type do
    defp executable_extension, do: ".bat"
  else
    defp executable_extension, do: ""
  end
end
