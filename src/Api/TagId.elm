module Api.TagId exposing
    ( TagId
    , decoder
    , encode
    , fromRoute
    , toString
    )

import Json.Decode as Decode
import Json.Encode as Encode
import Route exposing (Route)


type TagId
    = TagId String


decoder : Decode.Decoder TagId
decoder =
    Decode.string
        |> Decode.map TagId


encode : TagId -> Encode.Value
encode (TagId tagId) =
    Encode.string tagId


toString : TagId -> String
toString (TagId tagId) =
    tagId


fromRoute : Route { tagId : String } -> TagId
fromRoute route =
    TagId route.params.tagId
