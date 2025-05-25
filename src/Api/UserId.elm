module Api.UserId exposing
    ( UserId
    , decoder
    , encoder
    , fromRoute
    , toString
    )

import Json.Decode as Decode
import Json.Encode as Encode
import Route exposing (Route)


type UserId
    = UserId String


decoder : Decode.Decoder UserId
decoder =
    Decode.string
        |> Decode.map UserId


encoder : UserId -> Encode.Value
encoder (UserId userId) =
    Encode.string userId


toString : UserId -> String
toString (UserId userId) =
    userId


fromRoute : Route { userId : String } -> UserId
fromRoute route =
    UserId route.params.userId
