module Components.ErrorSummary exposing (view)

import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes as Attributes
import Http.DetailedError exposing (DetailedError)


view :
    { formErrors : Dict String (List String)
    , maybeError : Maybe DetailedError
    }
    -> Html msg
view props =
    case ( Dict.isEmpty props.formErrors, props.maybeError ) of
        ( _, Just err ) ->
            Html.output
                [ Attributes.class "block p-4 mb-4 bg-red-50 rounded-xl border-2 border-red-500 border-solid" ]
                [ Html.h2 [ Attributes.class "text-lg font-bold" ] [ Html.text "There is a problem" ]
                , Html.text (Http.DetailedError.toString err)
                ]

        ( False, _ ) ->
            Html.output
                [ Attributes.class "block p-4 mb-4 bg-red-50 rounded-xl border-2 border-red-500 border-solid" ]
                [ Html.h2 [ Attributes.class "text-lg font-bold" ] [ Html.text "There is a problem" ]
                , Html.ul
                    [ Attributes.class "list-disc list-inside text-red-700" ]
                    (Dict.toList props.formErrors
                        |> List.map
                            (\( key, errors ) ->
                                case errors of
                                    [] ->
                                        Html.text ""

                                    error :: _ ->
                                        Html.li
                                            [ Attributes.class "text-sm" ]
                                            [ Html.a
                                                [ Attributes.href ("#" ++ key)
                                                , Attributes.target "_self"
                                                , Attributes.class "underline decoration-2 decoration-red-500 underline-offset-2"
                                                ]
                                                [ Html.text (key ++ ": " ++ error) ]
                                            ]
                            )
                    )
                ]

        _ ->
            Html.text ""
