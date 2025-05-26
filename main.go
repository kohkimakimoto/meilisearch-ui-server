package main

import (
	"embed"
	"errors"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
)

//go:embed dist
var embeddedDistFS embed.FS

var Version = "dev"

func main() {
	if err := realMain(); err != nil {
		log.Fatal(err)
	}
}

func realMain() error {
	var distFS = echo.MustSubFS(embeddedDistFS, "dist")
	var port string

	// Options
	flag.StringVar(&port, "port", "24900", "Listen port. Default is 24900. You can also use PORT environment variable.")

	flag.VisitAll(func(f *flag.Flag) {
		// Set the flag value from the environment variable if the variable exists.
		name := f.Name
		if s := os.Getenv(strings.Replace(strings.ToUpper(name), "-", "_", -1)); s != "" {
			_ = f.Value.Set(s)
		}
	})

	flag.Usage = func() {
		fmt.Print(`Usage: meilisearch-ui-server [OPTIONS...]

A simeple web server to serve meilisearch-ui.

Options:
  -port N           Listen port. Default is 24900. You can also use PORT environment variable.
  -h, -help         Show help.

Version: ` + Version + `
`)
	}
	flag.Parse()

	e := echo.New()
	e.HideBanner = true

	e.Use(middleware.Logger())
	e.Use(middleware.Recover())

	// Static files
	e.StaticFS("/", distFS)

	// Start the server
	if err := e.Start(":" + port); err != nil && !errors.Is(err, http.ErrServerClosed) {
		return err
	}
	return nil
}
