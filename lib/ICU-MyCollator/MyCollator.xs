#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifdef __cplusplus
}
#endif

#include <iostream>
#include <unicode/coll.h>
using namespace std;

class MyCollator {
private:
	Locale* locale;
	Collator* collator;
public:
	MyCollator(const char *language, const char *country=0, const char *variant=0): locale(NULL),collator(NULL) {
		locale = new Locale(language, country, variant);
		if (locale->isBogus()) {
			delete locale;
			locale = NULL;
			croak("Locale not supported");
		}
		/* cout << locale->getLanguage() << endl; */
		UErrorCode err = U_ZERO_ERROR;
		collator = Collator::createInstance(*locale, err);
		if (U_FAILURE(err)) {
			delete locale;
			locale = NULL;
			croak("Unable to create the instance of collator %s\n", u_errorName(err));
		}
		collator->setAttribute(UCOL_CASE_FIRST, UCOL_UPPER_FIRST, err);
		/*collator->setAttribute(UCOL_CASE_LEVEL, UCOL_ON, err); */
	}
	~MyCollator() {
		if (collator) {
		    delete collator;
		}
		if (locale) {
		    delete locale;
		}
	}
	int compare(const char* a, const char* b) {
		UnicodeString strA(a, "utf8");
		UnicodeString strB(b, "utf8");

		UErrorCode err = U_ZERO_ERROR;
		UCollationResult result = collator->compare(strA, strB, err);

		if (U_FAILURE(err)) {
			croak("Unable to compare strings %s\n", u_errorName(err));
		}

		if (result == UCOL_EQUAL) {
			return 0;
		} else if (result == UCOL_GREATER) {
			return 1;
		} else {
			return -1;
		}
	}
};

MODULE = ICU::MyCollator		PACKAGE = ICU::MyCollator

MyCollator *
MyCollator::new(const char *language, const char *country=0, const char *variant=0)

void
MyCollator::DESTROY()

int
MyCollator::compare(const char* a, const char* b)
