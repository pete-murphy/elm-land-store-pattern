module Store.Request exposing (..)

import Http
import Json.Decode
import Paginated
import Url.Builder


type alias Key =
    ( List String, String )


type Request config a
    = Request Internals (Json.Decode.Decoder a) config


type Msg config
    = Msg Internals config


type alias Internals =
    { headers : List Http.Header
    , pathSegments : List String
    , queryParams : List Url.Builder.QueryParameter
    }



-- GETTERS


msg : Request config a -> Msg config
msg (Request internals _ config_) =
    Msg internals config_


key : Msg config -> Key
key (Msg internals _) =
    ( internals.pathSegments, Url.Builder.toQuery internals.queryParams )


config : Msg config -> config
config (Msg _ config_) =
    config_


headers : Msg config -> List Http.Header
headers (Msg internals _) =
    internals.headers


pathSegments : Msg config -> List String
pathSegments (Msg internals _) =
    internals.pathSegments


queryParams : Msg config -> List Url.Builder.QueryParameter
queryParams (Msg internals _) =
    internals.queryParams


decoder : Request config a -> Json.Decode.Decoder a
decoder (Request _ decoder_ _) =
    decoder_



-- CONSTRUCTORS


unpaginated :
    { pathSegments : List String
    , queryParams : List Url.Builder.QueryParameter
    , headers : List Http.Header
    , decoder : Json.Decode.Decoder a
    }
    -> Request () a
unpaginated args =
    Request
        { pathSegments = args.pathSegments
        , queryParams = args.queryParams
        , headers = args.headers
        }
        args.decoder
        ()


paginated :
    { pathSegments : List String
    , queryParams : List Url.Builder.QueryParameter
    , headers : List Http.Header
    , decoder : Json.Decode.Decoder a
    , config : Paginated.Config
    }
    -> Request Paginated.Config a
paginated args =
    Request
        { pathSegments = args.pathSegments
        , queryParams = args.queryParams
        , headers = args.headers
        }
        args.decoder
        args.config
