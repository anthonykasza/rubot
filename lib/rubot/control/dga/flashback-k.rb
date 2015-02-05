################################################################
# flashback-k_dga.rb
# Mac OS X Flashback.K Domain Generation Algorithm (DGA) Script
# Author of Python version: Brett Stone-Gross <bstonegross@secureworks.com>
# Maintainer of Ruby version
# Special thanks to Marc-Etienne M.Leveille <leveille@eset.com>
################################################################

module Rubot
	module Control
		module DGA
			class Flashback
				def initialize
					@static_domains = [ "rfffnahfiywyd.kz", "rfffnahfiywyd.in", "rfffnahfiywyd.info", "rfffnahfiywyd.net", "rfffnahfiywyd.com", "cvsqsmuiaaiyh.kz", "cvsqsmuiaaiyh.in", "cvsqsmuiaaiyh.info", "cvsqsmuiaaiyh.net", "cvsqsmuiaaiyh.com", "scfoijdccqtmj.kz", "scfoijdccqtmj.in", "scfoijdccqtmj.info", "scfoijdccqtmj.net", "scfoijdccqtmj.com", "gcnxqqdsbvplb.kz", "gcnxqqdsbvplb.in", "gcnxqqdsbvplb.info", "gcnxqqdsbvplb.net", "gcnxqqdsbvplb.com", "lbmracifhomjs.kz", "lbmracifhomjs.in", "lbmracifhomjs.info", "lbmracifhomjs.net", "lbmracifhomjs.com", "ahvpufwqnqcad.com", "kkkgmnbgzrajkk.com", "duuriklcxwdqduj.com", "kypekqpgwtvjud.com", "hwhmzdebnnfld.com", "ttveqlurnvnvjg.com", "pyutrmnalrfsa.com", "hyrussgnnaosas.com", "gbnmxgrucwgpew.com", "wqvrmapyjisdf.com", "tzvulcdovswll.com", "snefmftspawaa.com", "mwdhfqtevddz.com", "ocbelvodhpuu.com", "qpjlagydkmnm.com", "fzvmiozlzxqs.com", "qsyfcfmukmiqq.com", "mgmuloyfopbrna.net", "bzdtheaihrwkxth.com", "ozpvwivilizpzss.com", "mi13hthdtwdfhet.com", "sebaskasibpjwi.net", "dtruyfmrempenk.com", "lpjwscxnwpqkaq.com", "pioqzqzsthpcva.net"]
					@suffixes = [".com", ".net", ".info", ".in", ".kz"]
				end
				
				def uint8(num)
					num & 0xff
				end
				
				def uint32(num)
					num & 0xffffffff
				end
				
				def generate(date=Time.now)
					if date.respond_to? :strftime
						date = date.strftime("%Y-%m-%d")
					end
          a_ord = 0
          if 'a'.respond_to?(:ord)
            a_ord = 'a'.ord
          else
            a_ord[0]
          end
					year, month, day = date.split(/\-/)
					year = year.to_i - 1900
					month = month.to_i - 1
					day = day.to_i
					
					day_mangle1 = day ^ uint32(day << 16)
					if day_mangle1 <= 1
						day_mangle2 = uint32(day << 24)
						day_mangle3 = uint32(~(uint32(day << 24)))
						if day_mangle2 > 1
							day_mangle3 = day_mangle2
						end
						day_mangle1 = day_mangle3
					end

					month_mangle1 = month ^ uint32(month << 16)
					if month_mangle1 <= 7
						month_mangle1 = uint32(month << 24)
						if month_mangle1 <= 7
							month_mangle1 = uint32(~(uint32(month << 24)))
						end
					end

					year_mangle1 = year ^ uint32(year << 16)
 					if  year_mangle1 <= 0xF
						year_mangle2 = uint32(year << 24)
						year_mangle3 = uint32(~year_mangle2)
						if year_mangle2 > 0xF
							year_mangle3 = year_mangle2
						end
						year_mangle1 = year_mangle3
					end

					domain_len = (uint8(16 * (month_mangle1 & 0xF8)) ^ uint8((month_mangle1 ^ uint32(4 * month_mangle1)) >> 25) ^ uint8((day_mangle1 ^ uint32(day_mangle1 << 13)) >> 19) ^ uint8((year_mangle1 ^ uint32(8 * year_mangle1)) >> 11)) & 3
					domain_len += 12

					domain = ""
					0.upto(domain_len-1) do |i|
						day_mangle1 = ((day_mangle1 ^ uint32(day_mangle1 << 13)) >> 19) ^ uint32((day_mangle1 & 0xFFFFFFFE) << 12)
						month_mangle1 = ((month_mangle1 ^ uint32(4 * month_mangle1)) >> 25) ^ uint32(16 * (month_mangle1 & 0xFFFFFFF8))
						year_mangle1 = ((year_mangle1 ^ uint32(8 * year_mangle1)) >> 11) ^ uint32((year_mangle1 & 0xFFFFFFF0) << 17)
            domain += ((year_mangle1 ^ month_mangle1 ^ day_mangle1) % 25 + a_ord).chr
					end
					domains = [] #@static_domains.clone
					@suffixes.each do |suffix|
						domains << (domain+suffix)
					end
					domains
				end
			end
		end
	end
end
