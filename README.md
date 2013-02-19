Call Center
===========

Support for defining call center workflows.

[![Build Status](https://secure.travis-ci.org/zendesk/call_center.png)](http://travis-ci.org/zendesk/call_center)

Overview
--------
Call Center streamlines the process of defining multi-party call workflows in your application. Particularly, with [Twilio](http://www.twilio.com/docs) in mind.

[Twilio](http://www.twilio.com/docs) provides a two-part API for managing phone calls, and is mostly driven by callbacks. Call Center DRYs up the application logic dealing with a callback driven API so you can focus on the business logic of your call center.

Usage
-----

```ruby
class Call
  include CallCenter

  call_flow :state, :intial => :incoming do
    actor :customer do |call, event|
      "/voice/calls/flow?event=#{event}&actor=customer&call_id=#{call.id}"
    end

    state :incoming do
      response do |x|
        x.Gather :numDigits => '1', :action => customer(:wants_voicemail) do
          x.Say "Hello World"
          x.Play some_nice_music, :loop => 100
        end
        # <?xml version="1.0" encoding="UTF-8" ?>
        # <Response>
        #   <Gather numDigits="1" action="/voice/calls/flow?event=wants_voicemail&actor=customer&call_id=5000">
        #     <Say>Hello World</Say>
        #     <Play loop="100">http://some.nice.music.com/1.mp3</Play>
        #   </Gather>
        # </Response>
      end

      event :called, :to => :routing, :if => :agents_available?
      event :called, :to => :voicemail
      event :wants_voicemail, :to => :voicemail
      event :customer_hangs_up, :to => :cancelled
    end

    state :voicemail do
      response do |x|
        x.Say "Please leave a message"
        x.Record(:action => customer(:voicemail_complete))
        # <?xml version="1.0" encoding="UTF-8" ?>
        # <Response>
        #   <Say>Please leave a message</Say>
        #   <Record action="/voice/calls/flow?event=voicemail_complete&actor=customer&call_id=5000"/>
        # </Response>
      end

      event :voicemail_complete, :to => :voicemail_completed
      event :customer_hangs_up, :to => :cancelled
    end

    state :routing do

    end
  end
end
```

Benefits of **CallCenter** is that it's backed by [state_machine](https://github.com/pluginaweek/state_machine). Which means you can interact with events the same you do in `state_machine`.

```ruby
@call.called!
@call.wants_voicemail!
@call.routing?
@call.render # See Rendering
```

Flow
----

The general application flow for a **CallFlow** is like this:

1. An incoming call is posted to your application
   * You create a **Call**
   * You execute an initial event
   * You respond by rendering TwiML. Your TwiML contains callbacks to events or redirects
2. Something happens and Twilio posts an event to your application
   * You find the **Call**
   * You store any new information
   * You execute the posted event
   * You respond by rendering TwiML. Your TwiML contains callbacks to events or redirects
3. Repeat 2.

In order to DRY up the callbacks, it is best to have use standardized callback URLs. A handy concept is the `flow_url`, which follows the pattern:

    http://domain.com/calls/flow?call_id=?&event=?

By handling this in your controller, you can immediately retrieve the **Call** from persistence, run an event on the call, and return the rendered TwiML. Here's an example:

```ruby
def flow
  render :xml => @call.run(params[:event])
end
```

For an in-depth example, take a look at [call_roulette](https://github.com/zendesk/call_roulette).

Rendering
---------

Rendering is your way of interacting with Twilio. Thus, it provides two facilities: access to an XML builder and access to your call.

```ruby
state :sales do
  response do |xml_builder, the_call|
    xml_builder.Say "This is #{the_call.agent.name}!" # Or agent.name, you can access he call implicitly
  end
end
```

Renders with `@call.render` if the current state is :sales:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Say>This is Henry!</Say>
</Response>
```

Callbacks
---------

You have control over what you want to happen before/after state transitions:

```ruby
state :voicemail do
  before(:always) { # Invokes before any transition }
  before(:always, :uniq => true) { # Invokes before transitions to a different state }

  after(:always) { # Invokes after any transition }
  after(:success) { # Invokes after any successful transition }
  after(:failure) { # Invokes after any failed transition (those not covered in your call flow) }

  after(:always, :uniq => true) { # Invokes after any transition to a different state }
  after(:success, :uniq => true) { # Successful unique transitions }
  after(:failure, :uniq => true) { # Failed unique transitions }
end
```

For example,

```ruby
state :voicemail do
  before(:always) { log_start_event }

  after(:always) { log_end_event }
  after(:failure) { notify_airbrake }

  after(:success, :uniq => true) { notify_browser }
  after(:failure, :uniq => true) { notify_cleanup_browser }
end
```

Motivation
----------

### Not DRY
Twilio requests your application to return [TwiML](http://www.twilio.com/docs/api/twiml/) that describes the call workflow. TwiML contains commands which Twilio then executes. It is essentially an application-to-application API, synonymous to making a REST call.

In the context of "[Skinny Controller, Fat Model](http://weblog.jamisbuck.org/2006/10/18/skinny-controller-fat-model)", outgoing REST calls for the function of business logic are not a view concern but a model concern. Therefore, so is TwiML.

Twilio supports callbacks URLs and redirects to URLs that also render TwiML as a method of modifying live calls. Incoming callbacks are handled by the controller first, but the response is still a model concern.


Terminology
-----------

* **Call** - An application resource of yours that encapsulates a phone call. Phone calls are then acted on: answered, transferred, declined, etc.
* **Event** - Is something that happens outside or inside your application in relation to a **Call**. Someone picks up, hangs up, presses a button, etc. But overall, it's anything that can be triggered by Twilio callbacks.
* **State** - Is the status a **Call** is in which is descriptive of what's happened so far and what are the next things that should happen. (e.g. a call on hold is waiting for the agent to return)
* **CallFlow** - Is a definition of the process a **Call** goes through. **Events** drive the flow between **States**. (e.g. a simple workflow is when noone answers the call, send the call to voicemail)
* **Render** - Is the ability of the **CallFlow** to return TwiML to bring the call into the **State** or modify the live call through a **Redirect**.
* **Redirect** - Is a way of modifying a live call outside of a TwiML response (e.g. background jobs)

Tools
-----

### Drawing ###

Should you be interested in what your call center workflow looks like, you can draw.

```ruby
Call.state_machines[:status].draw(:font => 'Helvetica Neue')
# OR
@call.draw_call_flow(:font => 'Helvetica Neue')
```

Future
------

* Integrate making new calls into the **CallFlow** DSL

## Copyright and license

Copyright 2013 Zendesk

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
