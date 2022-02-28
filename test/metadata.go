package main

import (
	"log"
	"os"

	"github.com/go-playground/validator"
	"gitlab.eng.vmware.com/tap/tap-packages/scripts/pkg"
	"gopkg.in/yaml.v3"
)

type PackageMetadataCR struct {
	APIVersion string `yaml:"apiVersion"`
	Kind       string `yaml:"kind"`
	Metadata   struct {
		Name string `yaml:"name" validate:"required"`
	} `yaml:"metadata" validate:"required"`
	Spec struct {
		DisplayName      string `yaml:"displayName" validate:"required"`
		LongDescription  string `yaml:"longDescription" validate:"required"`
		ShortDescription string `yaml:"shortDescription" validate:"required"`
		ProviderName     string `yaml:"providerName" validate:"required"`
		Maintainers      []struct {
			Name string `yaml:"name"`
		} `yaml:"maintainers" validate:"required"`
		SupportDescription string `yaml:"supportDescription" validate:"required"`
	} `yaml:"spec" validate:"required"`
}

func GetPackageMetadataFile(fpath string) PackageMetadataCR {
	inputBytes, err := os.ReadFile(fpath)
	pkg.CheckError(err)
	pkgm := PackageMetadataCR{}
	err = yaml.Unmarshal(inputBytes, &pkgm)
	pkg.CheckError(err)
	return pkgm
}

var validate *validator.Validate

func main() {
	fpath := os.Args[1]
	log.Printf("Validating file extention...")
	pkg.CheckFileExtension(fpath, ".yaml")
	pkgm := GetPackageMetadataFile(fpath)
	log.Printf("Validating package metadata CR file: %s", fpath)
	validate = validator.New()
	err := validate.Struct(pkgm)
	if err != nil {
		validationErrors := err.(validator.ValidationErrors)
		log.Println(validationErrors)
		for _, err := range validationErrors {
			log.Println("Field ", err.StructNamespace(), "is", err.Tag())
			log.Println()
		}
	} else {
		log.Println("package metadata CR file:", fpath, "validated successfully")
	}

}
