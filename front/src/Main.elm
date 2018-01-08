module Main exposing (..)

import Data exposing (..)
import Html exposing (..)
import Html.Attributes exposing (class, classList, href, target, value)
import Html.Events exposing (onClick, onInput)
import Http
import Navigation exposing (Location)
import Request
import Route
import Series


main : Program Never Model Msg
main =
    Navigation.program Goto
        { init = init
        , update = update
        , view = view
        , subscriptions = always Sub.none
        }



-- MODEL


type alias Model =
    { index : List Series
    , query : String
    , series : Maybe Series.Model
    , pendingRequests : Int
    }


init : Location -> ( Model, Cmd Msg )
init location =
    let
        ( model, cmd1 ) =
            update (Goto location)
                { index = []
                , query = ""
                , pendingRequests = 1
                , series = Nothing
                }

        cmd2 =
            Request.index |> Http.send LoadIndex
    in
    ( model, Cmd.batch [ cmd1, cmd2 ] )



-- UPDATE


type Msg
    = LoadIndex (Result Http.Error (List Series))
    | LoadSeries (Result Http.Error Series)
    | UpdateQuery String
    | Select String
    | Reset
    | Goto Location
    | SeriesMsg Series.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        done model =
            { model | pendingRequests = model.pendingRequests - 1 }
    in
    case msg of
        LoadIndex (Ok index) ->
            done { model | index = index } ! []

        LoadIndex (Err error) ->
            done { model | index = [] } ! []

        LoadSeries (Ok series) ->
            done { model | query = series.primaryTitle, series = Just <| Series.init series } ! []

        LoadSeries (Err error) ->
            done { model | series = Nothing } ! []

        UpdateQuery query ->
            { model | query = query } ! []

        Select id ->
            { model | query = "" }
                ! [ Navigation.newUrl ("/" ++ id) ]

        Reset ->
            { model | series = Nothing, query = "" } ! []

        Goto location ->
            case Route.parse location of
                Just Route.Home ->
                    model ! []

                Just (Route.Series id) ->
                    { model | pendingRequests = model.pendingRequests + 1 }
                        ! [ Request.series id |> Http.send LoadSeries ]

                Nothing ->
                    model ! []

        SeriesMsg msg ->
            case model.series of
                Just series ->
                    let
                        ( series2, cmd ) =
                            Series.update msg series
                    in
                    { model | series = Just series2 } ! [ cmd |> Cmd.map SeriesMsg ]

                Nothing ->
                    model ! []



-- VIEW


view : Model -> Html Msg
view model =
    let
        query =
            model.query |> String.toLower

        filtered =
            model.index
                |> List.filter (\series -> series.primaryTitle |> String.toLower |> String.contains query)
                |> List.sortBy
                    (\series ->
                        let
                            first =
                                if series.primaryTitle |> String.toLower |> String.startsWith query then
                                    0
                                else
                                    1

                            second =
                                -series.rating.count
                        in
                        ( first, second )
                    )
                |> List.take 12

        isJust maybe =
            case maybe of
                Just _ ->
                    True

                Nothing ->
                    False

        isNothing =
            not << isJust

        when condition node =
            if condition then
                node
            else
                text ""
    in
    div []
        [ h1 [ class "ui center aligned header", onClick Reset ] [ text "tv.obtuse.io" ]
        , div
            [ class "ui fluid search dropdown selection active visible"
            , classList
                [ ( "current", isJust model.series )
                , ( "loading", model.pendingRequests > 0 )
                ]
            ]
            [ i [ class "dropdown icon" ] []
            , input [ class "search", value model.query, onClick Reset, onInput UpdateQuery ] []
            , div [ class "default text", classList [ ( "filtered", query /= "" ) ] ]
                [ text "Type the name of the show here..."
                ]
            , when (isNothing model.series) <|
                div [ class "menu transition visible" ]
                    (filtered
                        |> List.map
                            (\series ->
                                div [ class "item", onClick (Select series.id) ]
                                    [ text <|
                                        series.primaryTitle
                                            ++ " ("
                                            ++ toString series.rating.average
                                            ++ "/10 from "
                                            ++ toString series.rating.count
                                            ++ " votes)"
                                    ]
                            )
                    )
            ]
        , case model.series of
            Just series ->
                Series.view series |> Html.map SeriesMsg

            Nothing ->
                text ""
        ]
