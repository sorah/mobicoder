require 'tmpdir'
require 'fileutils'
require 'cgi'

module Mobicoder
  VIM = ENV["PATHTOVIM"] || "vim"
  NUL = /mswin|mingw|cygwin/ =~ RUBY_PLATFORM ? "NUL" : "/dev/null"
  class << self
    def run(base,to,from,*addfiles)
      Dir.mktmpdir("mobicoder") do |dir|
        files = (Dir[from]+addfiles).map do |x|
          a =  [File.expand_path(x)]
          a <<  CGI.escapeHTML(a[0].sub(File.expand_path(base),""))
          a <<  CGI.escape(a[0].sub(File.expand_path(base),""))
          a <<  File.join(dir,a[2])
        end.reject{|x| File.directory?(x[0]) }
        #f[0]: real path
        #f[1]: display name
        #f[2]: for hash
        #f[3]: to...

        files.each do |f|
          puts "converting: #{f[1]}"
          Mobicoder.convert(f, f[3], base)
        end
        Mobicoder.merge(dir, files, base)

        Dir.chdir(dir)
        puts "generating .mobi ..."
        system "kindlegen", "-o", File.basename(to), File.join(dir,"index.opf")
        FileUtils.mv(File.join(dir, File.basename(to)),to)
      end
    end

    def convert(from, to, base)
      system VIM, "-c", "set noswapfile",
                  "-c", "e #{from[0]}",
                  "-c", "colorscheme default",
                  "-c", "set nonu",
                  "-c", "TOhtml",
                  "-c", "w! #{to.gsub("%","\\%")}| qa!"#,
      #           :out => NUL, :err => NUL
      a = File.read(to)

      open(to,"w") do |io|
        io.puts "<a name=\"#{from[2]}\" /><h2>#{from[1]}</h2>"
        io.puts a.gsub(/.+<body>\n<pre>/m,"<pre>") \
                 .gsub(/<\/pre>\n<\/body>.+/m,"</pre>")
        io.puts "<mbp:pagebreak />"
      end; nil
    end

    def merge(dir, files, base)
      title = File.basename(File.expand_path(base))
      open(File.join(dir,"index.html"), "w") do |io|
        io.puts <<-EOH
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
<meta http-equiv="content-type" content="text/html; charset=UTF-8">
<title>#{title}</title>
<style type="text/css">
<!--
pre { font-family: monospace; color: #cccccc; background-color: #000000; }
body { font-family: monospace; color: #cccccc; background-color: #000000; }
.lnr { color: #666666; }
.Comment { color: #87ceeb; }
.Statement { color: #6699ff; }
.Identifier { color: #99ff00; }
.Type { color: #ffcc66; }
.Constant { color: #ffcc66; }
.Special { color: #ffdead; }
.PreProc { color: #ff6666; }
-->
</style>
</head>
<body>
        <h1>#{title}</h1>
        EOH
        io.puts '<a name="TOC" /><h2>Files</h2>'
        files.each do |f|
          io.puts "<p><a href=\"##{f[2]}\">#{f[1]}</a></p>"
        end
        io.puts "<mbp:pagebreak />"
        files.each do |f|
          io.puts File.read(f[3])
        end
        io.puts "</body></html>"
      end
      open(File.join(dir,"toc.ncx"), "w") do |io|
        io.puts <<-EOX
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE ncx PUBLIC "-//NISO//DTD ncx 2005-1//EN" "http://www.daisy.org/z3986/2005/ncx-2005-1.dtd">

<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">

   <docTitle><text>#{title}</text></docTitle>

   <navMap>
        EOX
        files.each_with_index do |f,i|
          io.puts <<-EOX
     <navPoint id="navPoint-#{i+1}" playOrder="#{i+1}">
       <navLabel><text></text></navLabel><content src="index.html#{"#"+f[2]}"/>
     </navPoint>
          EOX
        end
        io.puts <<-EOX
   </navMap>
</ncx>
        EOX

      end
      open(File.join(dir,"index.opf"),"w") do |io|
        io.puts <<-EOX
<?xml version="1.0" encoding="utf-8"?>
<package unique-identifier="uid">
  <metadata>
    <dc-metadata xmlns:dc="http://purl.org/metadata/dublin_core"
    xmlns:oebpackage="http://openebook.org/namespaces/oeb-package/1.0/">

      <dc:Title>#{title}</dc:Title>
      <dc:Language>en-us</dc:Language>
      <dc:Date>#{Time.now.strftime("%m/%d/%Y")}</dc:Date>
    </dc-metadata>
    <x-metadata>
      <output encoding="utf-8" content-type="text/x-oeb1-document">
      </output>
    </x-metadata>
  </metadata>
  <manifest>
    <item id="item1" media-type="text/x-oeb1-document" href="index.html"></item>
    <item id="toc" media-type="application/x-dtbncx+xml" href="toc.ncx"></item>
  </manifest>
  <spine toc="toc">
    <itemref idref="item1" />
  </spine>
  <tours></tours>
  <guide>
    <reference type="toc" title="Table of Contents" href="index.html%23TOC"></reference>
    <reference type="start" title="Startup Page" href="index.html%23TOC"></reference>
  </guide>
</package>
        EOX
      end
        puts File.join(dir,"index.opf")
        puts File.join(dir,"toc.ncx")
        STDIN.gets
    end
  end
end
