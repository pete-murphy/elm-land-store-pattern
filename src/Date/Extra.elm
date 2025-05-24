module Date.Extra exposing
    ( decoder
    , encode
    , testSuite
    , toIntlProps
    , toPosix
    )

{-| `Date` is the type to use when the corresponding Haskell type is `Day`.

We want to avoid parsing those as `Posix` because it can lead to the following
kind of bug:

    > newYork = Time.customZone (-300) []
    > format = DateFormat.format [ DateFormat.dayOfMonthNumber ] newYork
    > decoded = Decode.decodeString Iso8601.decoder "\"2024-11-25\""
    > Result.map format decoded
    Ok "24"

-}

import Date exposing (Date)
import Expect
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Test exposing (Test)
import Time exposing (Month(..))
import Time.Extra


{-| Convert `Date` to `Time.Posix` / UTC timestamp.

If you need to display the resulting `Posix` to the user, you will need to use
the `Time.utc` time zone to show the date correctly.

-}
toPosix : Date -> Time.Posix
toPosix date =
    Time.Extra.partsToPosix Time.utc
        { year = Date.year date
        , month = Date.month date
        , day = Date.day date
        , hour = 0
        , minute = 0
        , second = 0
        , millisecond = 0
        }



-- JSON


{-| Decode a date from an ISO string, e.g. "2020-01-01".

This matches the behavior of the `FromJSON` instance for `Day` in Haskell,
which has its implementation here:
<https://hackage.haskell.org/package/text-iso8601-0.1.1/docs/src/Data.Time.FromText.html#parseDay_>

-}
decoder : Decoder Date
decoder =
    Decode.string
        |> Decode.andThen
            (\str ->
                case Date.fromIsoString str of
                    Ok date ->
                        Decode.succeed date

                    Err _ ->
                        Decode.fail "Invalid date"
            )


{-| Encode a date to an ISO string, e.g. "2020-01-01".
-}
encode : Date -> Value
encode date =
    Encode.string (Date.toIsoString date)



-- HTML


{-| A date string and time-zone string that can be used with
`Intl.DateTimeFormat` (via `<sl-format-date>` for example) to format a date.
-}
toIntlProps :
    Date
    ->
        { date : String
        , timeZone : String
        }
toIntlProps date =
    { date = Date.toIsoString date ++ "T00:00Z"
    , timeZone = "utc"
    }



-- TESTS


testSuite : Test
testSuite =
    Test.describe "Date.Extra"
        [ Test.test "decodes a date" <|
            \() ->
                let
                    date =
                        Date.fromCalendarDate 2020 Jan 1
                in
                Expect.equal (Ok date) (Decode.decodeString decoder "\"2020-01-01\"")
        , Test.test "encodes a date" <|
            \() ->
                let
                    date =
                        Date.fromCalendarDate 2020 Jan 1
                in
                Expect.equal "\"2020-01-01\"" (Encode.encode 0 (encode date))
        ]
