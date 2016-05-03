# ActiveSupport::OperationLogger

adds ActiveRecord-like logging to anything you want

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'active_support-operation_logger'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install active_support-operation_logger

## Usage

```rb
require 'active_support-operation_logger'

ActiveSupport::OperationLogger.log_calls_on! MyKlass
ActiveSupport::OperationLogger.log_calls_on! Redis::Client, event_namespace: 'redis', only: :call
```

