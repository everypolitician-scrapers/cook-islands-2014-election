#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'open-uri'
require 'colorize'

require 'pry'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read) 
end

def scrape_list(url)
  noko = noko_for(url)
  # binding.pry
  section = noko.xpath('.//h3/span[@class="mw-headline" and contains(.,"By constituency")]')
  section.xpath('.//following::table[.//th[contains(.,"Candidate")]]').each do |table|
    constituency = table.css('tr').first.text[/2014: (.*)/, 1]
    winner = table.xpath('.//tr[td]').map { |tr|
      tds = tr.css('td')
      next if tds.any? { |td| td.attr('colspan') }
      data = { 
        party: tds[0].text.tidy,
        name: tds[1].text.tidy,
        wikipedia: tds[1].xpath('a[not(@class="new")]/@href').text,
        wikipedia_title: tds[1].xpath('a[not(@class="new")]/@title').text,
        constituency: constituency,
        votes: tds[2].text.to_i,
      }
      # https://en.wikipedia.org/wiki/Mitiaro_by-election_2014
      data[:votes] -= 1 if data[:name] == 'Tuakeu Tangatapoto'
      data
    }.compact.sort_by { |d| d[:votes] }.reverse.take(1)
    puts winner
    ScraperWiki.save_sqlite([:name, :constituency], winner)
  end
end

scrape_list('https://en.m.wikipedia.org/wiki/Cook_Islands_general_election,_2014')
