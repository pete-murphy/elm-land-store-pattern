module Html.Parser.Extra exposing (decoder)

import Html.Parser
import Json.Decode exposing (Decoder)


decoder : Decoder (List Html.Parser.Node)
decoder =
    Json.Decode.string
        |> Json.Decode.andThen
            (\str ->
                case Html.Parser.run str of
                    Ok nodes ->
                        Json.Decode.succeed nodes

                    Err _ ->
                        Json.Decode.fail "Failed to parse HTML"
            )
