use std::num::NonZeroU16;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct Port(NonZeroU16);

impl Port {
    pub fn new(value: u16) -> Result<Self, String> {
        NonZeroU16::new(value)
            .map(Self)
            .ok_or_else(|| "Ports must be between 1 and 65535.".into())
    }

    pub fn get(self) -> u16 {
        self.0.get()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn rejects_zero_and_accepts_port_boundaries() {
        assert!(Port::new(0).is_err());
        assert_eq!(Port::new(1).unwrap().get(), 1);
        assert_eq!(Port::new(65535).unwrap().get(), 65535);
    }
}
