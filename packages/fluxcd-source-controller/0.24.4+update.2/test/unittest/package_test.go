package sourcecontroller

import (
	"log"
	"os"
	"regexp"
	"strings"
	"testing"

	"github.com/go-playground/validator"
	"github.com/stretchr/testify/require"
	"gitlab.eng.vmware.com/tap/tap-packages/scripts/pkg"
	"gopkg.in/yaml.v3"
)

type PackageCR struct {
	APIVersion string `yaml:"apiVersion"`
	Kind       string `yaml:"kind"`
	Metadata   struct {
		Name string `yaml:"name"`
	} `yaml:"metadata"`
	Spec struct {
		RefName    string `yaml:"refName"`
		Version    string `yaml:"version" validate:"required"`
		ReleasedAt string `yaml:"releasedAt" validate:"ISO8601date"`
		Template   struct {
			Spec struct {
				Fetch []struct {
					ImgpkgBundle struct {
						Image string `yaml:"image"`
					} `yaml:"imgpkgBundle"`
				} `yaml:"fetch"`
				Template []struct {
					Kbld struct {
						Paths []string `yaml:"paths"`
					} `yaml:"kbld,omitempty"`
					Ytt struct {
						Paths []string `yaml:"paths"`
					} `yaml:"ytt,omitempty"`
				} `yaml:"template"`
				Deploy []struct {
					Kapp struct {
					} `yaml:"kapp"`
				} `yaml:"deploy"`
			} `yaml:"spec"`
		} `yaml:"template" validate:"required"`
	} `yaml:"spec"`
}

func GetPackageFile(fpath string) (PackageCR, error) {
	pkgFile := PackageCR{}
	inputBytes, err := os.ReadFile(fpath)
	if err == nil {
		err = yaml.Unmarshal(inputBytes, &pkgFile)
	}

	return pkgFile, err
}

func IsISO8601Date(fl validator.FieldLevel) bool {
	ISO8601DateRegexString := "^(-?(?:[1-9][0-9]*)?[0-9]{4})-(1[0-2]|0[1-9])-(3[01]|0[1-9]|[12][0-9])(?:T|\\s)(2[0-3]|[01][0-9]):([0-5][0-9]):([0-5][0-9])?(Z)?$"
	ISO8601DateRegex := regexp.MustCompile(ISO8601DateRegexString)
	return ISO8601DateRegex.MatchString(fl.Field().String())
}

func TestPackageStruct(t *testing.T) {
	fpath := "../../package.yaml"
	pkg.CheckFileExtension(fpath, ".yaml")
	packageFile, err := GetPackageFile(fpath)
	require.NoError(t, err)

	// ValidateImage(packageFile.Spec.Template.Spec.Fetch[0].ImgpkgBundle.Image)
	ValidateTemplateSection(packageFile)
	validate = validator.New()
	validate.RegisterValidation("ISO8601date", IsISO8601Date)
	err = validate.Struct(packageFile)
	if err != nil {
		validationErrors := err.(validator.ValidationErrors)
		log.Println(validationErrors)
		for _, err := range validationErrors {
			if err.Tag() == "ISO8601date" {
				log.Fatalln("Please provide field ", err.StructNamespace(), "in format", err.Tag())
			} else {
				log.Fatalln("Field ", err.StructNamespace(), "is", err.Tag())
			}
			log.Println()
		}
	} else {
		log.Println("package CR file:", fpath, "validated successfully")
	}
}

func ValidateImage(Image string) {
	log.Println("Validating Image", Image)
	InValidImage := strings.Contains(Image, "pivotal.io")
	DevImage := strings.Contains(Image, "dev.registry.tanzu.vmware.com")
	ShaImage := strings.Contains(Image, "@sha256:")
	if InValidImage || !DevImage {
		log.Fatalln("Please provide image reference which points to dev.registry.tanzu.vmware.com")
	}
	if !ShaImage {
		log.Fatalln("Please provide bundle image in digested form instead of tag")
	}
	log.Println("Image reference in package CR is validated successfully")
}

func ValidateTemplateSection(packageFile PackageCR) {
	isKbldPresent, isPathPresentInKbldPath := false, false
	for _, template := range packageFile.Spec.Template.Spec.Template {
		if len(template.Kbld.Paths) != 0 {
			isKbldPresent = true
			for _, path := range template.Kbld.Paths {
				if path == ".imgpkg/images.yml" {
					isPathPresentInKbldPath = true
					break
				}
			}
		}
	}
	if !isKbldPresent {
		log.Fatal("kbld entry is absent in the template section.")
	}
	if !isPathPresentInKbldPath {
		log.Fatal(`".imgpkg/images.yml" entry is absent in the kbld, in the template section.`)
	}
	log.Print("template section validated successfully.")
}
