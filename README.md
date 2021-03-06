AvoiRMLdupois
===========

ARML-providing Point of interest (POI) server.

## Issues

There are no known ARML-using clients.  Still, we have to start somewhere.

## Requirements

AvoiRMLdupois is written in [Ruby](http://www.ruby-lang.org/en/) using the [Sinatra](http://www.sinatrarb.com/) web application framework.  It uses ActiveRecord from Ruby on Rails to talk to the database, but this will probably change.

You will need to have Ruby and [Rubygems](http://rubygems.org/) installed for this to work.  You can either do that through a package manager or by using [RVM](https://rvm.io/), which is probably easiest in the long run and will help you avoid problems with different Ruby versions.

You will also need [Git](http://git-scm.com/) to get this source code.

    $ sudo apt-get install git

[Bundler](http://bundler.io/) manages the required Ruby gems such as Sinatra. You may need to preface this command with `sudo` if you're not using RVM:

    $ gem install bundler

While I'm at it, let me recommend two other useful tools: [curl](http://curl.haxx.se/) and [jsonlint](https://github.com/zaach/jsonlint).

    $ sudo apt-get install curl
    $ sudo apt-get install npm
	$ npm install jsonlint -g

All of these installation commands are meant for Debian/Ubuntu; adapt them to your system if you run something different.

## Installation

### The source code

To install AvoiRMLdupois you need to get this source code by either forking this GitHub repository or downloading it directly.  This will clone the repository, download all the files, and show what's there:

    $ git clone git@github.com:wdenton/avoirmldupois.git
    $ cd avoirmldupois
    $ ls
	$ bundle install

### Setting up databases

Before going any further you need to set up the databases AvoiRMLdupois will use.  The configuration details are in [config/database.yml](config/database.yml).

	$ cp config/database.yml.sample config/database.yml

You must use PostgreSQL.  Assuming it is installed, run these commands:

    $ sudo -u postgres psql --command "CREATE ROLE avoirmldupois LOGIN PASSWORD 'arml';"
	$ sudo -u postgres psql --command "ALTER USER avoirmldupois CREATEDB;"

Then

    # bundle exec rake db:create
    # bundle exec rake db:migrate

(If you are using RVM then you may be able to leave out "bundle exec" on those.)

### Running the web service (out of date)

Now you can run the actual web service.

    $ bundle install
    $ bundle exec rackup config.ru

You should now see a message like this:

    [2013-09-23 20:38:21] INFO  WEBrick 1.3.1
    [2013-09-23 20:38:21] INFO  ruby 2.0.0 (2013-06-27) [x86_64-linux]
    [2013-09-23 20:38:21] INFO  WEBrick::HTTPServer#start: pid=26438 port=9292

Good! This means that the web service is running on your machine on port 9292.  You can now test it by pretending you're at (-79.39717, 43.66789), the corner of Bloor and Bedford in Toronto, midway between three of the sample POIs. Hit it on the command line (from another shell) like so, or visit the URL directly in a browser:

    $ curl "http://localhost:9292/sample&lon=-79.39717&lat=43.66789&radius=1000"

You'll get an error because there is no such layer 'sample':

    {
      "errorCode": 22,
      "errorString": "No such layer sample"
    }

### Loading sample data (out of date)

To create the sample layer, run

	$ ./loaders/loader.rb loaders/sample/sample.geojson
	Creating sample ...
    Gardiner Museum
      Action: Web site
      Icon: Gardiner Museum
    Royal Ontario Museum
      Action: Web site
      Icon: Royal Ontario Museum
    Bata Shoe Museum
      Action: Web site
      Icon: Bata Shoe Museum
    Textile Museum of Canada
      Action: Web site
      Icon: Textile Museum of Canada
    Mackenzie House
      Action: Web site
      Icon: Mackenzie House
    No checkboxes to configure

Now rerun the request:

    $ curl "http://localhost:9292/?layerName=sample&lon=-79.39717&lat=43.66789&version=6.2&radius=1000"

It should respond with JSON output (as defined in Layar's [GetPOIs Response](https://www.layar.com/documentation/browser/api/getpois-response/)).

If you installed `jsonlint` then this will make the output more readable:

    $ curl "http://localhost:9292/?layerName=sample&lon=-79.39717&lat=43.66789&version=6.2&radius=1000" | jsonlint
    {
      "layer": "sample",
      "showMessage": "This is a sample layer in Layar.",
      "refreshDistance": 100,
      "refreshInterval": 300,
      "hotspots": [
        {
          "id": 2,
          "text": {
            "title": "Royal Ontario Museum",
            "description": "A major museum for history and world culture.",
            "footnote": ""
          },
          "anchor": {
            "geolocation": {
              "lat": 43.6682,
              "lon": -79.3952
            }
          },
        [ ... and a lot more ... ]

That simple request is how Layar will get points of interest from AvoiRMLdupois. Layar passes in more variables, but the core are:

* layerName: the name of the layer
* lon: longitude of user
* lat: latitude of user
* version: version of Layar client app
* radius: how far (in meters) to look for POIs

## Loading in POIS (out of date)

The easiest way to create a layer and load in a set of POIs is to make a GeoJSON file and load it with `loader.rb`.  Aside from the sample layers you might also look at [campus-tour.geojson](loaders/campus-tour/campus-tour.geojson), a small set of six POIs for the [Alternative Campus Tour](http://alternativecampustour.info.yorku.ca/) at York University.  Copy an existing GeoJSON file, edit the layer name and POIs, and load it in as above.  ([GeoJSON](http://geojson.org/) is a flexible and friendly format for storing this information. It's easily mapped, including here on GitHub, which renders GeoJSON files as maps.  [GeoJSONLint](http://geojsonlint.com/) may be helpful for checking your files. The Layar documentation explains what each field in the file means.)

Another way is to use ActiveRecord to construct POI objects and save them. This is how [load-york-data.rb](loaders/york/load-york-data.rb) works to set up POIs for the view of York University's campuses.  It pulls in POIs from a few sources and constructs and saves the POI object directly, which for various reasons is easier than dumping to a file and loading that. See the [README](loaders/york/load-york-data/README.md) for more.

## Putting into production

AvoiRMLdupois uses [Rack](http://rack.github.io/), so it can be deployed with [Phusion Passenger](https://www.phusionpassenger.com/) or however else you like to deploy such applications.  I do it with this:

    <VirtualHost *:80>
        ServerName avoirmldupois.miskatonic.org
        DocumentRoot /var/www/avoirmldupois.miskatonic.org/avoirmldupois/public
        SetEnv RACK_ENV production
        <Directory /var/www/avoirmldupois.miskatonic.org/avoirmldupois>
            Allow from all
            Options -MultiViews
        </Directory>
        ErrorLog ${APACHE_LOG_DIR}/avoirmldupois.error.log
        LogLevel debug
        CustomLog ${APACHE_LOG_DIR}/avoirmldupois.access.log combined
    </VirtualHost>

Then, as before:

* Set up database (avoirmldupois)
* Clone code as above
* Initialize
* Load layers

    $ RACK\_ENV=production ./initialize.rb
    $ RACK\_ENV=production ./loaders/loader.rb campus-tour/campus-tour.geojson
    $ RACK\_ENV=production ./loaders/york/load-york-data.rb

## To do

* Include database setup script.
* Write tests and use them.
* Is there better way to initialize the database, with rake or something?
* Explain more about loading data.
* Better implementation of distance restriction.
* Limit to closest 50 POIs.
