class Mono < Formula
  desc "Cross platform, open source .NET development framework"
  homepage "https://www.mono-project.com/"
  url "https://download.mono-project.com/sources/mono/mono-6.4.0.198.tar.xz"
  sha256 "d00852822525e36f9f8b3e0f537d3a41c7a718cac22d06fc63ea64988877c2ea"

  bottle do
    sha256 "8cdcf8b776f2574121281da6b84cc90d0b0f079e36fd730965bb7e6ba5e1b4a3" => :mojave
    sha256 "d3c6c5391a74d0bf6ff7abbfdf710cded891e3901e50ed9d732c393e7a404386" => :high_sierra
    sha256 "7d5f52e1e09f291e87a6b4f46daaa8417be5e7774c106396965cac8d1fb3f5bf" => :sierra
  end

  depends_on "cmake" => :build
  depends_on "pkg-config" => :build

  conflicts_with "xsd", :because => "both install `xsd` binaries"

  # xbuild requires the .exe files inside the runtime directories to
  # be executable
  skip_clean "lib/mono"

  link_overwrite "bin/fsharpi"
  link_overwrite "bin/fsharpiAnyCpu"
  link_overwrite "bin/fsharpc"
  link_overwrite "bin/fssrgen"
  link_overwrite "lib/mono"
  link_overwrite "lib/cli"

  unless OS.mac?
    depends_on "python@2" => :build
    depends_on "unzip" => :build
  end

  resource "fsharp" do
    url "https://github.com/fsharp/fsharp.git",
        :tag      => "10.2.3",
        :revision => "e31bc96e8a5e5742af1c6c45d55d5cc06bb524cb"
  end

  # When upgrading Mono, make sure to use the revision from
  # https://github.com/mono/mono/blob/mono-#{version}/packaging/MacSDK/msbuild.py
  resource "msbuild" do
    url "https://github.com/mono/msbuild.git",
        :revision => "ad9c9926a76e3db0d2b878a24d44446d73640d19"
  end

  def install
    system "./configure", "--prefix=#{prefix}",
                          "--disable-silent-rules",
                          "--enable-nls=no"
    system "make"
    system "make", "install"
    # mono-gdb.py and mono-sgen-gdb.py are meant to be loaded by gdb, not to be
    # run directly, so we move them out of bin
    libexec.install bin/"mono-gdb.py", bin/"mono-sgen-gdb.py"

    # We'll need mono for msbuild, and then later msbuild for fsharp
    ENV.prepend_path "PATH", bin

    # Next build msbuild
    resource("msbuild").stage do
      system "./eng/cibuild_bootstrapped_msbuild.sh", "--host_type", "mono", "--configuration", "Release", "--skip_tests"
      system "./artifacts/mono-msbuild/msbuild", "mono/build/install.proj",
             "/p:MonoInstallPrefix=#{prefix}", "/p:Configuration=Release-MONO",
             "/p:IgnoreDiffFailure=true"
    end

    # Finally build and install fsharp as well
    resource("fsharp").stage do
      ENV.prepend_path "PKG_CONFIG_PATH", lib/"pkgconfig"
      system "make"
      system "make", "install"
    end
  end

  def caveats; <<~EOS
    To use the assemblies from other formulae you need to set:
      export MONO_GAC_PREFIX="#{HOMEBREW_PREFIX}"
  EOS
  end

  test do
    test_str = "Hello Homebrew"
    test_name = "hello.cs"
    (testpath/test_name).write <<~EOS
      public class Hello1
      {
         public static void Main()
         {
            System.Console.WriteLine("#{test_str}");
         }
      }
    EOS
    shell_output("#{bin}/mcs #{test_name}")
    output = shell_output("#{bin}/mono hello.exe")
    assert_match test_str, output.strip

    # Tests that xbuild is able to execute lib/mono/*/mcs.exe
    (testpath/"test.csproj").write <<~EOS
      <?xml version="1.0" encoding="utf-8"?>
      <Project ToolsVersion="4.0" DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
        <PropertyGroup>
          <AssemblyName>HomebrewMonoTest</AssemblyName>
          <TargetFrameworkVersion>v4.5</TargetFrameworkVersion>
        </PropertyGroup>
        <ItemGroup>
          <Compile Include="#{test_name}" />
        </ItemGroup>
        <Import Project="$(MSBuildBinPath)\\Microsoft.CSharp.targets" />
      </Project>
    EOS
    system bin/"xbuild", "test.csproj"

    # Test that fsharpi is working
    ENV.prepend_path "PATH", bin
    (testpath/"test.fsx").write <<~EOS
      printfn "#{test_str}"; 0
    EOS
    output = pipe_output("#{bin}/fsharpi test.fsx")
    assert_match test_str, output

    # Tests that xbuild is able to execute fsc.exe
    (testpath/"test.fsproj").write <<~EOS
      <?xml version="1.0" encoding="utf-8"?>
      <Project ToolsVersion="4.0" DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
        <PropertyGroup>
          <ProductVersion>8.0.30703</ProductVersion>
          <SchemaVersion>2.0</SchemaVersion>
          <ProjectGuid>{B6AB4EF3-8F60-41A1-AB0C-851A6DEB169E}</ProjectGuid>
          <OutputType>Exe</OutputType>
          <FSharpTargetsPath>$(MSBuildExtensionsPath32)\\Microsoft\\VisualStudio\\v$(VisualStudioVersion)\\FSharp\\Microsoft.FSharp.Targets</FSharpTargetsPath>
        </PropertyGroup>
        <Import Project="$(FSharpTargetsPath)" Condition="Exists('$(FSharpTargetsPath)')" />
        <ItemGroup>
          <Compile Include="Main.fs" />
        </ItemGroup>
        <ItemGroup>
          <Reference Include="mscorlib" />
          <Reference Include="System" />
          <Reference Include="FSharp.Core" />
        </ItemGroup>
      </Project>
    EOS
    (testpath/"Main.fs").write <<~EOS
      [<EntryPoint>]
      let main _ = printfn "#{test_str}"; 0
    EOS
    system bin/"xbuild", "test.fsproj"
  end
end
