# Jacaranda

*A watchful tree and extensible Slack messenger to keep you informed of how your civic tech projects are being used.*

> Not everything that can be counted counts, and not everything that counts can be counted.
> (Albert Einstine, on the wall of his study in Princeton. Quoted in [*Can We Know Better?*, Robert Chambers, 2017](http://www.developmentbookshelf.com/doi/book/10.3362/9781780449449))

This project is an attempt to get useful information about how a project is used, to the people who maintain, run, and build it.

While working on [PlanningAlerts](https://www.planningalerts.org.au) we’ve noticed that:

* We don’t have an accurate idea of the impact of PlanningAlerts, how many people are using it, or the rate a which this is changing; and
* We feel more energised in our work when we get feedback about it’s use and impact.

Jacaranda is an experiment to see the impact of regular feedback on the people developing PlanningAlerts. It aims to keep you more informed of the use and impact of PlanningAlerts; to remind you of the effort you’ve put in to achieve this; and to do this in an quick and unobtrusive way.

Jacaranda collects information about people using PlanningAlerts and the work we do to make it better for them. It then sends a short fortnightly message to our Slack channel to give us a sense of how things are going.

![Image of slack message from Jacaranda](screenshot.jpg)

This is a very basic start. We’ve interested to see how getting these messages impacts us and what we do with the information.

## PlanningAlerts message

Currently Jacaranda tells you about:

* the number of people who signed up for PlanningAlerts in the last fortnight;
* the difference between this number and the figure for the previous fortnight;
* the number of people who have unsubscribed in the last fortnight;
* the difference between this number and the figure for the previous fortnight;
* the number of commits pushed to the project in the last fortnight; and,
* the total number of people now signed up to PlanningAlerts.

While the number of users isn’t a great measure of PlanningAlerts’ impact, it’s a start to see how the feedback works for us. Feel free to change the text or the information in presents to what you think will have a better impact.

### Caveats

The time frames that this claims to show subscribers for aren’t accurate because they're displayed as it they were recorded in local time, but they're actually counted in UTC.

## Right To Know message

Currently Jacaranda tells you about:

* The number of new requests in the last fortnight
* The number of annotations in the last fortnight
* The number of requests that were successful in the last fortnight

## Quickstart

Ensure you have Ruby + Bundler installed, then run:

``` bash
git clone https://github.com/openaustralia/jacaranda.git
cd jacaranda
bundle
```

Then run the scraper with:

``` bash
bundle exec ruby scraper.rb
```

And run the tests with:

``` bash
bundle exec rspec
```

## Usage

The scraper looks for these environment variables:

* `MORPH_RUNNERS`, a comma separated list of runners to execute. If you don't set this, Jacaranda will execute all known runners. You can use the `--list-runners` option to get a list of all runners Jacaranda knows about.
* `MORPH_RUNNERS_RIGHTTOKNOW_WEBHOOK_URL`, the webhook URL to post _Right To Know_ messages to Slack. You can get a URL by adding an _Incoming Webhook_ customer integration in your Slack org.
* `MORPH_RUNNERS_RIGHTTOKNOW_WEBHOOK_CHANNEL`, the Slack channel to post _Right To Know_ messages into.
* `MORPH_RUNNERS_PLANNINGALERTS_WEBHOOK_URL`, the webhook URL to post _PlanningAlerts_ messages to Slack. You can get a URL by adding an _Incoming Webhook_ customer integration in your Slack org.
* `MORPH_RUNNERS_PLANNINGALERTS_WEBHOOK_CHANNEL`, the Slack channel to post _PlanningAlerts_ messages into.
* `MORPH_LIVE_MODE`, to determine if the scraper actually posts to Slack and saves a record of the post to the database. Defaults to `false`.

When developing locally, you can add these environment variables to a [`.env` file](https://github.com/bkeepers/dotenv) so the scraper loads them when it runs:

``` bash
MORPH_LIVE_MODE=false
```

Create a `.env` file using the supplied example by running:

```
cp .env.example .env
```

Then edit to taste.

### Running the scraper on morph.io

You can also run this as a scraper on [Morph](https://morph.io).

To get started [see the documentation](https://morph.io/documentation).

## Contributing

### Adding new runners to Jacaranda

Jacaranda has a very simple model for adding new runners.

Runners pull information from (sometimes multiple) sources, and posts a message into Slack.

To add a new runner, create a file in `lib/runners/` and define the following class:

``` ruby
# lib/runners/my_service.rb
module MyService
  # A new runner for my new service
  class Runner < Jacaranda::BaseRunner
    class << self
      def build
        [
          'My text here.'
        ]
      end
    end
  end
end
```

Then run the scraper:

``` bash
MORPH_LIVE_MODE=false bundle exec ruby scraper.rb --runners MyService
```

*Note: The `--runners` option is used only in development. Morph will run the scraper with no arguments.*

*Note: You can use the `--list-runners` option to get a list of all runners Jacaranda knows about.*

You'll see output something like this:

```
These are the runners we will execute:

MyService

[MyService] We have not posted an update during this fortnight.
[MyService] Not posting to Slack.
[MyService] Not recording the message in the database.

> My text here.
```

That's it.

While displaying some static text is a nice start, you'll want to call out to your app to pull information in:

``` ruby
# lib/runners/my_service.rb
module MyService
  # A new runner for my new service
  class Runner < Jacaranda::BaseRunner
    class << self
      def build
        [
          MyService::Website.status_text(period: last_fortnight),
        ]
      end
    end
  end
end
```

We're using a built-in helper method called `last_fortnight` to give us a date range for the last fortnight:

``` ruby
last_fortnight # => [ Mon, 31 Jul 2017, Tue, 01 Aug 2017, ... ]
```

We pass this as the `period` parameter to the `status_text` method on the `Website` class.

Both the `MyApp` class and `status_text` method don't exist yet. Let's add them:

``` ruby
# lib/runners/my_service.rb

# MyApp stats from MyApp
module MyService
  class Website
    class << self
      def status_text(period:)
        [
          ':tada:',
          count('requests:new', period: period),
          'new requests were made through My Service in the last fortnight.'
        ].join(' ')
      end

      def count(query, period)
        start  = period.first
        finish = period.last

        # Make a call out to your service here ...
      end
    end
  end
end
```

The `status_text` method is very simple – it accepts a time period it needs to produce text for, and returns a string of text.

Typically there is a `count` method used to get hit some endpoint or scrape some pages, and generate aggregate statistics. The exact implementation is up to you! Check out the `PlanningAlerts` and `RightToKnow` runners to see some more complex use cases.

## Image credit

The Jacaranda Slack avatar is cropped from a [photograph of the Jacaranda trees on Gowrie St, Newtown, Sydney by Flickr user murry](https://www.flickr.com/photos/hopeless128/15808564051/in/photolist-aCSCXw-q8S). Thanks murry for making it available under a creative commons license.
