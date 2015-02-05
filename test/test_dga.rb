unless Kernel.respond_to?(:require_relative)
	module Kernel
		def require_relative(path)
			require File.join(File.dirname(caller[0]), path.to_str)
		end
	end
end

require_relative 'helper'
require 'digest/md5'

include Rubot::Control::DGA

class TestDGA < Minitest::Test
  def test_dga_bamital
		dga = Rubot::Control::DGA::Bamital.new("A","Z")
		correct_answer = ["bc60dde6d14f09a8a25480d29f511c68.co.cc",
		 "bc60dde6d14f09a8a25480d29f511c68.cz.cc",
		 "bc60dde6d14f09a8a25480d29f511c68.info",
		 "bc60dde6d14f09a8a25480d29f511c68.org",
		 "3e77292585cf88800dc326407a5b3895.co.cc",
		 "3e77292585cf88800dc326407a5b3895.cz.cc",
		 "3e77292585cf88800dc326407a5b3895.info",
		 "3e77292585cf88800dc326407a5b3895.org",
		 "7d4b066f8bb9a2538ec49e2cf3e46a5d.co.cc",
		 "7d4b066f8bb9a2538ec49e2cf3e46a5d.cz.cc",
		 "7d4b066f8bb9a2538ec49e2cf3e46a5d.info",
		 "7d4b066f8bb9a2538ec49e2cf3e46a5d.org",
		 "a17e14aa15d9fd171866074ba7c6d5d8.co.cc",
		 "a17e14aa15d9fd171866074ba7c6d5d8.cz.cc",
		 "a17e14aa15d9fd171866074ba7c6d5d8.info",
		 "a17e14aa15d9fd171866074ba7c6d5d8.org",
		 "79ec0417e3378252bca835169051e378.co.cc",
		 "79ec0417e3378252bca835169051e378.cz.cc",
		 "79ec0417e3378252bca835169051e378.info",
		 "79ec0417e3378252bca835169051e378.org",
		 "1df1df0130fbcb88a30fc0e12a573908.co.cc",
		 "1df1df0130fbcb88a30fc0e12a573908.cz.cc",
		 "1df1df0130fbcb88a30fc0e12a573908.info",
		 "1df1df0130fbcb88a30fc0e12a573908.org",
		 "70fbea121d9afeec0a0d93af21ffc161.co.cc",
		 "70fbea121d9afeec0a0d93af21ffc161.cz.cc",
		 "70fbea121d9afeec0a0d93af21ffc161.info",
		 "70fbea121d9afeec0a0d93af21ffc161.org",
		 "8d9c8e3ca0644882e4c6bd827bdb1b68.co.cc",
		 "8d9c8e3ca0644882e4c6bd827bdb1b68.cz.cc",
		 "8d9c8e3ca0644882e4c6bd827bdb1b68.info",
		 "8d9c8e3ca0644882e4c6bd827bdb1b68.org",
		 "6f1ad15daf8b712e6c0f1e706bf0524d.co.cc",
		 "6f1ad15daf8b712e6c0f1e706bf0524d.cz.cc",
		 "6f1ad15daf8b712e6c0f1e706bf0524d.info",
		 "6f1ad15daf8b712e6c0f1e706bf0524d.org",
		 "3fe5a3272ff21429167bc831dae0fbfd.co.cc",
		 "3fe5a3272ff21429167bc831dae0fbfd.cz.cc",
		 "3fe5a3272ff21429167bc831dae0fbfd.info",
		 "3fe5a3272ff21429167bc831dae0fbfd.org",
		 "1fa80006e02c5f4982a8c5ca26be9ce0.co.cc",
		 "1fa80006e02c5f4982a8c5ca26be9ce0.cz.cc",
		 "1fa80006e02c5f4982a8c5ca26be9ce0.info",
		 "1fa80006e02c5f4982a8c5ca26be9ce0.org",
		 "056a7c4c81c3b5874828250ac5f3bfa6.co.cc",
		 "056a7c4c81c3b5874828250ac5f3bfa6.cz.cc",
		 "056a7c4c81c3b5874828250ac5f3bfa6.info",
		 "056a7c4c81c3b5874828250ac5f3bfa6.org",
		 "52d72f3a5c661f646ff955a4f1c9dc4d.co.cc",
		 "52d72f3a5c661f646ff955a4f1c9dc4d.cz.cc",
		 "52d72f3a5c661f646ff955a4f1c9dc4d.info",
		 "52d72f3a5c661f646ff955a4f1c9dc4d.org",
		 "426bfa52148b4c944316655c0cb1f03a.co.cc",
		 "426bfa52148b4c944316655c0cb1f03a.cz.cc",
		 "426bfa52148b4c944316655c0cb1f03a.info",
		 "426bfa52148b4c944316655c0cb1f03a.org",
		 "f6677cbc0735112b3173294c7e323228.co.cc",
		 "f6677cbc0735112b3173294c7e323228.cz.cc",
		 "f6677cbc0735112b3173294c7e323228.info",
		 "f6677cbc0735112b3173294c7e323228.org",
		 "7f977dee503a99a2e3a78d6d5aa71c87.co.cc",
		 "7f977dee503a99a2e3a78d6d5aa71c87.cz.cc",
		 "7f977dee503a99a2e3a78d6d5aa71c87.info",
		 "7f977dee503a99a2e3a78d6d5aa71c87.org",
		 "51d94db0f5d6af7f3732153a43183520.co.cc",
		 "51d94db0f5d6af7f3732153a43183520.cz.cc",
		 "51d94db0f5d6af7f3732153a43183520.info",
		 "51d94db0f5d6af7f3732153a43183520.org",
		 "3e701d62189dee17078a29b15418cb32.co.cc",
		 "3e701d62189dee17078a29b15418cb32.cz.cc",
		 "3e701d62189dee17078a29b15418cb32.info",
		 "3e701d62189dee17078a29b15418cb32.org",
		 "fca4cc2f5f17efced7bd96fadfcb003d.co.cc",
		 "fca4cc2f5f17efced7bd96fadfcb003d.cz.cc",
		 "fca4cc2f5f17efced7bd96fadfcb003d.info",
		 "fca4cc2f5f17efced7bd96fadfcb003d.org",
		 "b2b96d01a8beb68441a6daa75ac6c665.co.cc",
		 "b2b96d01a8beb68441a6daa75ac6c665.cz.cc",
		 "b2b96d01a8beb68441a6daa75ac6c665.info",
		 "b2b96d01a8beb68441a6daa75ac6c665.org",
		 "77a7396707dca89a51338dbcb718792c.co.cc",
		 "77a7396707dca89a51338dbcb718792c.cz.cc",
		 "77a7396707dca89a51338dbcb718792c.info",
		 "77a7396707dca89a51338dbcb718792c.org",
		 "738b7d22355e3e4a69542c3db5d4ce09.co.cc",
		 "738b7d22355e3e4a69542c3db5d4ce09.cz.cc",
		 "738b7d22355e3e4a69542c3db5d4ce09.info",
		 "738b7d22355e3e4a69542c3db5d4ce09.org",
		 "a74e19b9a18bc2e0578353229e02ee16.co.cc",
		 "a74e19b9a18bc2e0578353229e02ee16.cz.cc",
		 "a74e19b9a18bc2e0578353229e02ee16.info",
		 "a74e19b9a18bc2e0578353229e02ee16.org",
		 "50da8885f75c1a18bb4b878c001d3364.co.cc",
		 "50da8885f75c1a18bb4b878c001d3364.cz.cc",
		 "50da8885f75c1a18bb4b878c001d3364.info",
		 "50da8885f75c1a18bb4b878c001d3364.org",
		 "b01dadf7559064d44c2163801c0cce52.co.cc",
		 "b01dadf7559064d44c2163801c0cce52.cz.cc",
		 "b01dadf7559064d44c2163801c0cce52.info",
		 "b01dadf7559064d44c2163801c0cce52.org",
		 "21038a235f63a1fd93abc11a8e39cae5.co.cc",
		 "21038a235f63a1fd93abc11a8e39cae5.cz.cc",
		 "21038a235f63a1fd93abc11a8e39cae5.info",
		 "21038a235f63a1fd93abc11a8e39cae5.org"]
		answer = dga.generate("2012-04-01")
		assert_equal(correct_answer,answer)
  end
  
  def test_dga_blackhole
		unix = Time.at(1343788966)
		correct_answer = "kzxrowftdocgyghs.ru"
		domain = Rubot::Control::DGA::Blackhole.new.generate(unix)
		assert_equal(correct_answer, domain)
  end
  
  def test_dga_conficker_like
		cfkr = Rubot::Control::DGA::Conficker::A.new
		doms = cfkr.generate("2012-04-01")
		md5 = Digest::MD5.new.hexdigest(doms.join(" "))
		assert_equal("ecc826c847787b9d846f4011014efa6a",md5)
		cfkr = Rubot::Control::DGA::Conficker::B.new
		doms = cfkr.generate("2012-04-01")
		md5 = Digest::MD5.new.hexdigest(doms.join(" "))
		assert_equal("8bda45e8cc2ea93e5ac7160c85d024f7",md5)
		cfkr = Rubot::Control::DGA::Conficker::C.new
		doms = cfkr.generate("2012-04-01")
		md5 = Digest::MD5.new.hexdigest(doms.join(" "))
		assert_equal("1228eaf9fa11272740e76a42856b8cc1",md5)    
  end
  
  def test_dga_flashback_k
		dga = Rubot::Control::DGA::Flashback.new
		correct_answer = "rfffnahfiywyd.kz rfffnahfiywyd.in rfffnahfiywyd.info rfffnahfiywyd.net rfffnahfiywyd.com cvsqsmuiaaiyh.kz cvsqsmuiaaiyh.in cvsqsmuiaaiyh.info cvsqsmuiaaiyh.net cvsqsmuiaaiyh.com scfoijdccqtmj.kz scfoijdccqtmj.in scfoijdccqtmj.info scfoijdccqtmj.net scfoijdccqtmj.com gcnxqqdsbvplb.kz gcnxqqdsbvplb.in gcnxqqdsbvplb.info gcnxqqdsbvplb.net gcnxqqdsbvplb.com lbmracifhomjs.kz lbmracifhomjs.in lbmracifhomjs.info lbmracifhomjs.net lbmracifhomjs.com ahvpufwqnqcad.com kkkgmnbgzrajkk.com duuriklcxwdqduj.com kypekqpgwtvjud.com hwhmzdebnnfld.com ttveqlurnvnvjg.com pyutrmnalrfsa.com hyrussgnnaosas.com gbnmxgrucwgpew.com wqvrmapyjisdf.com tzvulcdovswll.com snefmftspawaa.com mwdhfqtevddz.com ocbelvodhpuu.com qpjlagydkmnm.com fzvmiozlzxqs.com qsyfcfmukmiqq.com mgmuloyfopbrna.net bzdtheaihrwkxth.com ozpvwivilizpzss.com mi13hthdtwdfhet.com sebaskasibpjwi.net dtruyfmrempenk.com lpjwscxnwpqkaq.com pioqzqzsthpcva.net tomewpjgkeea.com tomewpjgkeea.net tomewpjgkeea.info tomewpjgkeea.in tomewpjgkeea.kz".split(/ /)
		simple_answer = "tomewpjgkeea.com tomewpjgkeea.net tomewpjgkeea.info tomewpjgkeea.in tomewpjgkeea.kz".split
		answer = dga.generate("2012-08-03")
		assert_equal(simple_answer, answer)
  end
  
  def test_dga_licat
		dga = Rubot::Control::DGA::Licat::V1.new(0xd6d7a4be)
		doms = dga.generate(Time.parse("2012-04-01"))
		md5 = Digest::MD5.new.hexdigest(doms.join(" "))
		assert_equal("a495e7ec702e3159a79d2a7cc69f2d30", md5)
    
		dga = Rubot::Control::DGA::Licat::V2.new
		doms = dga.generate(Time.parse("2012-04-01"))
		md5 = Digest::MD5.new.hexdigest(doms.join(" "))
		assert_equal("65553d7477fc5d948be8bc719b69ffa2", md5)
  end
  
  def test_dga_sribi
		returned = Rubot::Control::DGA::Srizbi.new(0x5BE741E3).generate("2008-11-13 12:00")
		answer = ["yrytdyip.com", "auaopagr.com", "qpqduqud.com", "ydywryfu.com"]
		assert_equal(answer, returned)
		returned = Rubot::Control::DGA::Srizbi.new(0x5BE741E3).generate("2008-11-17 12:00")
		answer = ["ererseqg.com","tutuitqf.com","upupruqd.com","ododgoqs.com"]
		assert_equal(answer, returned)
  end
  
end