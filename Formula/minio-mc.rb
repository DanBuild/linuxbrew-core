# minio-mc: Build a bottle for Linuxbrew
class MinioMc < Formula
  desc "Replacement for ls, cp and other commands for object storage"
  homepage "https://github.com/minio/mc"
  url "https://github.com/minio/mc.git",
      :tag      => "RELEASE.2019-09-24T01-36-20Z",
      :revision => "643835013047aa27ed35de0ac5a4ab9538f0cd68"
  version "20190924013620"

  bottle do
    cellar :any_skip_relocation
    sha256 "1db416c0d28b3b1cb48d31d52907c6055e1342e5fbf324f258dedf92447ffb66" => :mojave
    sha256 "a53909264b73fab0875bc13f53f8ea7f57bde2e536f0d538c6c0f95cea3c7e45" => :high_sierra
    sha256 "d3dfaf021f9abfc0bc63e5adf358ec0f3794873f5298f26d7f304dadaf6ea611" => :sierra
  end

  depends_on "go" => :build

  conflicts_with "midnight-commander", :because => "Both install a `mc` binary"

  def install
    ENV["GOPATH"] = buildpath
    src = buildpath/"src/github.com/minio/mc"
    src.install buildpath.children
    src.cd do
      if build.head?
        system "go", "build", "-o", buildpath/"mc"
      else
        minio_release = `git tag --points-at HEAD`.chomp
        minio_version = minio_release.gsub(/RELEASE\./, "").chomp.gsub(/T(\d+)\-(\d+)\-(\d+)Z/, 'T\1:\2:\3Z')
        minio_commit = `git rev-parse HEAD`.chomp
        proj = "github.com/minio/mc"

        system "go", "build", "-o", buildpath/"mc", "-ldflags", <<~EOS
          -X #{proj}/cmd.Version=#{minio_version}
          -X #{proj}/cmd.ReleaseTag=#{minio_release}
          -X #{proj}/cmd.CommitID=#{minio_commit}
        EOS
      end
    end

    bin.install buildpath/"mc"
    prefix.install_metafiles
  end

  test do
    system bin/"mc", "mb", testpath/"test"
    assert_predicate testpath/"test", :exist?
  end
end
