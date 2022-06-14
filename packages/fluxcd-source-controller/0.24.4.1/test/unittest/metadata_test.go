package sourcecontroller

import (
	"log"
	"os"
	"testing"

	"github.com/go-playground/validator"
	"github.com/stretchr/testify/require"
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

func TestMetadata(t *testing.T) {
	fpath := "../../../metadata.yaml"
	pkg.CheckFileExtension(fpath, ".yaml")
	pkgm := GetPackageMetadataFile(fpath)
	log.Printf("Validating package metadata CR file: %s", fpath)
	validate = validator.New()
	err := validate.Struct(pkgm)
	require.NoError(t, err)
}
