# Rubot

This gem will allow you to mock-up and modify various botnet models.

## Background

Rubot - Botnet Emulation Framework

Criminals use the anonymity and pervasiveness of the Internet to commit fraud, extortion, and theft. Botnets are used as the primary tool for this criminal activity. Botnets allow criminals to accumulate and covertly control multiple Internet-connected computers. They use this network of controlled computers to flood networks with traffic from multiple sources, send spam, spread infection, spy on users, commit click fraud, run adware, and host phishing sites. This presents serious privacy risks and financial burdens to businesses and individuals. Furthermore, all indicators show that the problem is worsening because the research and development cycle of the criminal industry is faster than that of security research.

To enable researchers to measure botnet connection models and counter-measures, a flexible, rapidly augmentable framework for creating test botnets is provided. This botnet framework, written in the Ruby language, enables researchers to run a botnet on a closed network and to rapidly implement new communication, spreading, control, and attack mechanisms for study. This is a significant improvement over augmenting C++ code-bases for the most popular botnets, Agobot and SDBot. Rubot allows researchers to implement new threats and their corresponding defenses before the criminal industry can. The Rubot experiment framework includes models for some of the latest trends in botnet operation such as peer-to-peer based control, fast-flux DNS, and periodic updates.

Our approach implements the key network features from existing botnets and provides the required infrastructure to run the botnet in a closed environment.

* [Dissertation Slides](http://chrisleephd.us/projects/rubot/rubot-defense.pdf)
* [Thesis](http://chrisleephd.us/projects/rubot/rubot-thesis.pdf)

## Installation

Add this line to your application's Gemfile:

    gem 'rubot'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rubot

### Debian/Ubuntu Users
Install the required packages

	sudo aptitude install screen git ruby bundler libsqlite3-dev sqlite3 ruby-dev tor hping3 nmap libgsl0-dev
	sudo /etc/init.d/tor start # if you plan to use tor in your experiment

Download the Code

	git clone https://github.com/chrislee35/rubot.git

Install the Ruby dependencies

	cd rubot
	bundle install

Test the install

	rake test
	# To do a specific test
	RUBYLIB=lib ruby test/test_file_name.rb
	# To run a specific test case (example)
	RUBYLIB=lib ruby test/test_http_server.rb -n test_use_a_custom_callback_for_the_http_server

## Usage

Currently, this is quite unusable :)  I'm still adding all the base functionality.  Look at the test cases for what is currently working.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
