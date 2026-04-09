abstract type AbstractMarketFeed end
abstract type AbstractOrderRouter end

function next_event! end
function current_time end
function is_exhausted end
function subscribe! end
function unsubscribe! end

function submit! end
function cancel! end
function replace! end
function fills end
