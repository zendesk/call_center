Call Center
===========

Support for defining call center workflows.

Overview
--------
Call Center streamlines the process of defining multi-party call workflows in your application. Particularly, with [Twilio](http://www.twilio.com/docs) in mind.

[Twilio](http://www.twilio.com/docs) provides a two-part API for managing phone calls, and is mostly driven by callbacks. Call Center DRYs up the application logic dealing with a callback driven API so you can focus on the business logic of your call center.

### Not DRY
Twilio requests your application to return [TwiML](http://www.twilio.com/docs/api/twiml/) that describes the call workflow. TwiML contains commands which Twilio then executes. It is essentially an application-to-application API, synonymous to making a REST call.

In the context of "[Skinny Controller, Fat Model](http://weblog.jamisbuck.org/2006/10/18/skinny-controller-fat-model)", outgoing REST calls for the function of business logic are not a view concern but a model concern. Therefore, so is TwiML.

Twilio supports callbacks URLs and redirects to URLs that also render TwiML as a method of modifying live calls. Incoming callbacks are handled by the controller first, but the response is still a model concern.

Terminology
-----------

* **Call** - An application resource of yours that encapsulates a phone call. Phone calls are then acted on: answered, transferred, declined, etc.
* **Event** - Is something that happens outside or inside your application in relation to a **Call**. Someone picks up, hangs up, presses a button, etc.
* **State** - Is the status a **Call** is in which is descriptive of what's happened so far and what are the next things that should happen. (e.g. a call on hold is waiting for the agent to return)
* **CallFlow** - Is a definition of the process a **Call** goes through. **Events** drive the flow between **States**. (e.g. a simple workflow is when noone answers the call, send the call to voicemail)
* **Render** - Is the ability of the **CallFlow** to return TwiML to bring the call into the **State** or modify the live call through a **Redirect**.
* **Redirect** - Is a way of modifying a live call outside of a TwiML response (e.g. background jobs)

Usage
-----

    class Call
      include CallCenter

      call_flow :state, :intial => :answered do
        state :answered do
          event :incoming_call, :to => :voicemail, :if => :not_during_business_hours?
          event :incoming_call, :to => :sales
        end

        state :voicemail do
          event :customer_hangs_up, :to => :voicemail_completed
        end

        on_render(:sales) do |call, x|
          x.Say "This is Sales!"
        end

        on_render(:voicemail) do |call, x|
          x.Say "Leave a voicemail!"
        end
      end
    end

Benefits of **CallCenter** is that it's backed by [state_machine](https://github.com/pluginaweek/state_machine). Which means you can interact with events the same you do in state_machine.

    @call.incoming_call!
    @call.voicemail?
    @call.sales?
    @call.render # See Rendering

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

Rendering
---------

Rendering is your way of interacting with Twilio. Thus, it provides two facilities: access to an XML builder and access to your call.

    on_render(:sales) do |the_call, xml_builder|
      xml_builder.Say "This is Sales!"
      
      the_call.flag! # You can access the call explicitly
      flag!          # Or access it implicitly
    end

Renders:

    <?xml version="1.0" encoding="UTF-8"?>
    <Response>
      <Say>This is Sales!</Say>
    </Response>

Redirects
---------

Redirects are a request made to the [Twilio REST API](http://www.twilio.com/docs/api/rest/) that points to a callback URL which returns TwiML to be executed on a call. It is up to you how you want to perform this (e.g. with your favority http libraries, or with [Twilio Libraries](http://www.twilio.com/docs/libraries/)).

Redirect to events look like this:

    ...
    call_flow :state, :intial => :answered do
      state :answered do
        ...
      end

      state :ending_call do
        event :end_call, :to => :ended_call
      end

      on_render(:ending_call) do
        redirect_and_end_call!(:status => 'completed')
      end
    end
    ...

For your **Call** to support this syntax, it must adhere to the following API:

    class Call
      def redirect_to(event, *args)
        # where:
        #   event #=> :end_call
        #   args  #=> [:status => 'completed]
        @account.calls.get(self.sid).update({:url => "http://myapp.com/call_flow?event=#{event}"})
      end
    end

Tools
-----

### Drawing ###

Should you be interested in what your call center workflow looks like, you can draw.

    Call.state_machines[:status].draw(:font => 'Helvetica Neue')
    # OR
    @call.draw_call_flow(:font => 'Helvetica Neue')

Future
------

* Integrate making new calls into the **CallFlow** DSL