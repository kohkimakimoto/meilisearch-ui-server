package main

import (
	"embed"
	"errors"
	"flag"
	"fmt"
	"io"
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

	// handle 404 response.
	// We need to handle 404 errors to serve index.html for SPA client-side routing.
	e.Use(func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			err := next(c)

			// If the file is not found, serve index.html for SPA client-side routing
			if err != nil && errors.Is(err, echo.ErrNotFound) {
				// read index.html for serving the SPA client-side routing.
				indexFile, err := distFS.Open("index.html")
				if err != nil {
					return fmt.Errorf("failed to open index.html: %w", err)
				}
				defer indexFile.Close()
				indexContent, err := io.ReadAll(indexFile)
				if err != nil {
					return fmt.Errorf("failed to read index.html: %w", err)
				}
				return c.HTMLBlob(http.StatusOK, indexContent)
			}

			return err
		}
	})

	// Static files
	e.StaticFS("/", distFS)

	// Start the server
	if err := e.Start(":" + port); err != nil && !errors.Is(err, http.ErrServerClosed) {
		return err
	}
	return nil
}
