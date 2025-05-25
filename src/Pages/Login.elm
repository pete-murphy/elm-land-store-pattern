module Pages.Login exposing (Model, Msg, page)

import Api.Auth exposing (LoginRequest)
import Components.Button as Button
import Components.ErrorSummary as ErrorSummary
import Dict exposing (Dict)
import Effect exposing (Effect)
import Form
import Form.Field as Field
import Form.FieldView as FieldView
import Form.Validation as Validation
import Html
import Html.Attributes as Attributes
import Http.DetailedError
import Loadable
import Page exposing (Page)
import Result.Extra
import Route exposing (Route)
import Shared
import Shared.Model
import Shared.Msg
import View exposing (View)


page : Shared.Model -> Route () -> Page Model Msg
page shared _ =
    Page.new
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = Result.Extra.unwrap (\_ -> View.none) (\ok -> view ok) shared
        }



-- INIT


type alias Model =
    { formModel : Form.Model
    , errors : Dict String (List String)
    }


init : () -> ( Model, Effect Msg )
init () =
    ( { formModel = Form.init
      , errors = Dict.empty
      }
    , Effect.sendMsg NoOp
    )



-- UPDATE


type Msg
    = FormMsg (Form.Msg Msg)
    | SharedMsg Shared.Msg
    | UserSubmittedInvalidLogin (Dict String (List String))
    | NoOp


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        FormMsg formMsg ->
            let
                ( updatedFormModel, cmd ) =
                    Form.update formMsg model.formModel
            in
            ( { model | formModel = updatedFormModel }
            , Effect.sendCmd cmd
            )

        SharedMsg sharedMsg ->
            ( model
            , Effect.sendSharedMsg sharedMsg
            )

        UserSubmittedInvalidLogin errors ->
            ( { model | errors = errors }
            , Effect.none
            )

        NoOp ->
            ( model
            , Effect.none
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Shared.Model.OkModel -> Model -> View Msg
view shared model =
    { title = "Login"
    , body =
        [ Html.div
            [ Attributes.class "grid place-items-center bg-gray-100 h-dvh" ]
            [ Html.main_ [ Attributes.class "p-8 w-full max-w-md bg-white rounded-xl shadow-lg outline-2 outline-gray-200/50" ]
                [ Html.h1
                    [ Attributes.class "mb-4 text-2xl font-bold" ]
                    [ Html.text "Login" ]
                , ErrorSummary.view { formErrors = model.errors, maybeError = Loadable.toMaybeError shared.credentials }
                , loginForm model.errors
                    |> Form.renderHtml
                        { submitting = Loadable.isLoading shared.credentials
                        , state = model.formModel
                        , toMsg = FormMsg
                        }
                        (Form.options "form"
                            |> Form.withOnSubmit
                                (\{ parsed } ->
                                    case parsed of
                                        Form.Valid { username, password } ->
                                            SharedMsg (Shared.Msg.UserSubmittedLogin { username = username, password = password })

                                        Form.Invalid _ errors ->
                                            UserSubmittedInvalidLogin errors
                                )
                        )
                        [ Attributes.class "grid gap-4" ]
                ]
            ]
        ]
    }



-- FORM


loginForm : Dict String (List String) -> Form.HtmlForm String LoginRequest input msg
loginForm errors =
    (\username password ->
        { combine =
            Validation.succeed LoginRequest
                |> Validation.andMap username
                |> Validation.andMap password
        , view =
            \formContext ->
                let
                    fieldView id label field attrs =
                        let
                            errorForField =
                                Dict.get id errors
                                    |> Maybe.andThen List.head
                        in
                        Html.div [ Attributes.class "grid gap-1" ]
                            [ Html.label
                                [ Attributes.class "text-sm font-semibold"
                                , Attributes.for id
                                ]
                                [ Html.text label ]
                            , case errorForField of
                                Just error ->
                                    Html.div
                                        [ Attributes.class "text-sm text-red-500" ]
                                        [ Html.text error ]

                                Nothing ->
                                    Html.text ""
                            , FieldView.input
                                (Attributes.class "py-2 px-4 w-full rounded-lg border border-gray-800 well-focus"
                                    :: Attributes.id id
                                    :: attrs
                                )
                                field
                            ]
                in
                [ fieldView "username"
                    "Username"
                    username
                    [ Attributes.attribute "autocapitalize" "off"
                    , Attributes.attribute "autocomplete" "username"
                    , Attributes.attribute "autocorrect" "off"
                    , Attributes.attribute "autofocus" "true"
                    , Attributes.spellcheck False
                    ]
                , fieldView "password"
                    "Password"
                    password
                    [ Attributes.attribute "autocomplete" "current-password"
                    ]
                , Button.new
                    |> Button.withLoading formContext.submitting
                    |> Button.withText "Log in"
                    |> Button.toHtml
                ]
        }
    )
        |> Form.form
        |> Form.field "username" (Field.text |> Field.email |> Field.required "Required")
        |> Form.field "password" (Field.text |> Field.password |> Field.required "Required")
