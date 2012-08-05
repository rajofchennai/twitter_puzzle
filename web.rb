require 'sinatra'
require 'rest-client'
require 'json'

TWITTER_MAX_PAGE_SIZE = 200
get '/' do
  "<html>
   <body>
     <h1> This form will return word_length as key and number of tweets for the word length as value </h1> <br/ >
     <form name='login' action='/screen_name' method='post'>
       Twitter handle <input type ='text' name='screen_name' /> <br />
       Include rts (anything other than true is false) <input type ='text' name='include_rts' /> <br />
       Exclue replies (anything other than true is false) <input type ='text' name='exclude_replies' /> <br />
       Tweets to consider (default 200, max 1000, non integers will be converted to 200) <input type ='text' name='max_count' /> <br />
         <input type ='Submit' value= 'Get numbers' /><br /><br />
         </form>
   </body>
  </html>"
end

post '/screen_name' do
  screen_name = params[:screen_name]
  if screen_name.nil? || screen_name == ""
    {:error => "should give some id"}.to_json
  else
    begin
      begin
        Integer params[:max_count]
      rescue
        params[:max_count] = ""
      end
      tw_request_url = "https://api.twitter.com/1/statuses/user_timeline.json?screen_name=#{screen_name}"
      tw_request_url += "&include_rts=true" if params[:include_rts] == 'true'
      tw_request_url += "&exclude_replies=true" if params[:exclude_replies] == 'true'
      params[:max_count] = params[:max_count].to_i if params[:max_count] != ""
      if params[:max_count] && params[:max_count] != "" && params[:max_count] > 1000
        params[:max_count] = 1000
      else
        params[:max_count] = TWITTER_MAX_PAGE_SIZE if params[:max_count] == ""
      end
      total_full_pages = params[:max_count] / TWITTER_MAX_PAGE_SIZE
      partial_page_length = params[:max_count] % TWITTER_MAX_PAGE_SIZE
      tweets = []
      1.upto total_full_pages do |page|
        response = RestClient.get tw_request_url+"&count=#{TWITTER_MAX_PAGE_SIZE}&page=#{page}"
        tweets.concat JSON.parse(response)
      end
      unless partial_page_length == 0
        response = RestClient.get tw_request_url+"&count=#{TWITTER_MAX_PAGE_SIZE}&page=#{total_full_pages+1}"
        tweets.concat JSON.parse(response)[0..partial_page_length-1]
      end
      # collecting word count of each of the tweets
      tweet_word_lengths = tweets.collect do |tweet|
        tweet['text'].split(' ').length
      end
      tweet_length_count = {}
      tweet_word_lengths.each do |tw_length|
        if tweet_length_count[tw_length]
          tweet_length_count[tw_length] += 1
        else
          tweet_length_count[tw_length] = 1
        end
      end

      "<h4> array of [tweet_length, number of tweets with tweet_length] in descending order of number of tweets</h4> <br /> <br /> "+(tweet_length_count.sort_by {|k,v| v}.reverse).inspect
    rescue RestClient::ResourceNotFound => xcp
      {:error => "#{screen_name} not found"}.to_json
    rescue RestClient::BadRequest
      {:error => "we think we hit the rate limit.. please try after sometime"}.to_json
    rescue SocketError
      {:error => "check your internet connection"}.to_json
    end
  end
end
