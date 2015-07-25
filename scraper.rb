#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'open-uri'
require 'colorize'
require 'wikidata'

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

def wikidata(title)
  return {} if title.to_s.empty?

  wd = Wikidata::Item.find_by_title title

  property = ->(elem, attr='title') { 
    prop = wd.property(elem) or return
    prop.send(attr)
  }

  fromtime = ->(time) { 
    return unless time
    DateTime.parse(time.time).to_date.to_s 
  }

  # party = P102
  # freebase = P646
  return { 
    wikidata: wd.id,
    family_name: property.('P734'),
    given_name: property.('P735'),
    image: property.('P18', 'url'),
    gender: property.('P21'),
    birth_date: fromtime.(property.('P569', 'value')),
  }
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
        term: 14,
        source: url,
      }
      data[:wikipedia] = URI.join('https://en.wikipedia.org/', data[:wikipedia]).to_s unless data[:wikipedia].to_s.empty?
      # https://en.wikipedia.org/wiki/Mitiaro_by-election_2014
      data[:votes] -= 1 if data[:name] == 'Tuakeu Tangatapoto'
      data
    }.compact.sort_by { |d| d[:votes] }.reverse.first
    winner.merge!  wikidata( winner[:wikipedia_title] )
    puts winner
    ScraperWiki.save_sqlite([:name, :constituency], winner)
  end
end

scrape_list('https://en.m.wikipedia.org/wiki/Cook_Islands_general_election,_2014')
